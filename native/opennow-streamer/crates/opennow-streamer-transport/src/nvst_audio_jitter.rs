use std::collections::VecDeque;
use std::sync::Arc;
use std::time::{Duration, Instant};

use str0m::rtp::RtpHeader;

const INITIAL_TARGET_MS: u64 = 45;
const MAX_TARGET_MS: u64 = 200;
const UNDERFLOW_INCREASE_MS: u64 = 20;
const MAX_PACKETS: usize = 80;
const MAX_PAYLOAD_BYTES: usize = 9 * 1275 + 33;

pub(crate) struct AudioPacket {
    pub header: RtpHeader,
    pub payload: Arc<[u8]>,
    pub received_at_us: u64,
}

#[derive(Debug, Default, PartialEq, Eq)]
pub(crate) struct AudioJitterStats {
    pub reordered: u64,
    pub stale: u64,
    pub overflow: u64,
    pub invalid: u64,
    pub source_resets: u64,
    pub underflows: u64,
}

pub(crate) struct AudioJitterBuffer {
    clock_rate_hz: u32,
    anchor: Option<(u32, u32, Instant)>,
    packets: VecDeque<AudioPacket>,
    last_played: Option<(u32, u16)>,
    target_ms: u64,
    late_burst: bool,
    pub stats: AudioJitterStats,
}

impl AudioJitterBuffer {
    pub fn new(clock_rate_hz: u32) -> Self {
        assert!(clock_rate_hz > 0);
        Self {
            clock_rate_hz,
            anchor: None,
            packets: VecDeque::with_capacity(MAX_PACKETS),
            last_played: None,
            target_ms: INITIAL_TARGET_MS,
            late_burst: false,
            stats: AudioJitterStats::default(),
        }
    }

    pub fn target_ms(&self) -> u64 {
        self.target_ms
    }

    pub fn len(&self) -> usize {
        self.packets.len()
    }

    fn deadline(&self, timestamp: u32) -> Instant {
        let (_, base_timestamp, base_time) = self.anchor.expect("packet has an anchor");
        let delta = timestamp.wrapping_sub(base_timestamp) as i32;
        let duration = Duration::from_micros(
            u64::from(delta.unsigned_abs()) * 1_000_000 / u64::from(self.clock_rate_hz),
        );
        let base_time = base_time + Duration::from_millis(self.target_ms);
        if delta < 0 {
            base_time.checked_sub(duration).unwrap_or(base_time)
        } else {
            base_time + duration
        }
    }

    pub fn push(&mut self, packet: AudioPacket, now: Instant) {
        if packet.payload.is_empty() || packet.payload.len() > MAX_PAYLOAD_BYTES {
            self.stats.invalid += 1;
            return;
        }
        let ssrc = *packet.header.ssrc;
        let timestamp = packet.header.timestamp;
        if self.anchor.is_none_or(|(source, _, _)| source != ssrc) {
            if self.anchor.is_some() {
                self.stats.source_resets += 1;
            }
            self.packets.clear();
            self.last_played = None;
            self.anchor = Some((ssrc, timestamp, now));
            self.target_ms = INITIAL_TARGET_MS;
            self.late_burst = false;
        }
        if self
            .last_played
            .is_some_and(|(played_timestamp, sequence)| {
                let delta = timestamp.wrapping_sub(played_timestamp) as i32;
                delta < 0
                    || packet.header.sequence_number.wrapping_sub(sequence) >= 0x8000
                    || packet.header.sequence_number == sequence
            })
            || self
                .packets
                .iter()
                .any(|queued| queued.header.sequence_number == packet.header.sequence_number)
        {
            self.stats.stale += 1;
            return;
        }
        let late = self.last_played.is_some() && now > self.deadline(timestamp);
        if late && !self.late_burst {
            self.stats.underflows += 1;
            self.target_ms = (self.target_ms + UNDERFLOW_INCREASE_MS).min(MAX_TARGET_MS);
        }
        self.late_burst = late;
        if self.deadline(timestamp).saturating_duration_since(now)
            > Duration::from_millis(MAX_TARGET_MS)
        {
            self.stats.overflow += self.packets.len() as u64;
            self.packets.clear();
            self.anchor = Some((ssrc, timestamp, now));
        }
        let index = self
            .packets
            .iter()
            .position(|queued| {
                let delta = timestamp.wrapping_sub(queued.header.timestamp) as i32;
                delta < 0
                    || (delta == 0
                        && (packet
                            .header
                            .sequence_number
                            .wrapping_sub(queued.header.sequence_number)
                            as i16)
                            < 0)
            })
            .unwrap_or(self.packets.len());
        if index < self.packets.len() {
            self.stats.reordered += 1;
        }
        self.packets.insert(index, packet);
        while self.packets.len() > MAX_PACKETS
            || self
                .packets
                .front()
                .zip(self.packets.back())
                .is_some_and(|(first, last)| {
                    u64::from(last.header.timestamp.wrapping_sub(first.header.timestamp)) * 1_000
                        > u64::from(self.clock_rate_hz) * MAX_TARGET_MS
                })
        {
            self.packets.pop_front();
            self.stats.overflow += 1;
        }
    }

    pub fn pop(&mut self, now: Instant) -> Option<AudioPacket> {
        let packet = self.packets.front()?;
        if now < self.deadline(packet.header.timestamp) {
            return None;
        }
        let packet = self.packets.pop_front()?;
        self.last_played = Some((packet.header.timestamp, packet.header.sequence_number));
        Some(packet)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn packet(sequence: u16, timestamp: u32) -> AudioPacket {
        AudioPacket {
            header: RtpHeader {
                sequence_number: sequence,
                timestamp,
                ssrc: 42.into(),
                ..RtpHeader::default()
            },
            payload: Arc::from([sequence as u8]),
            received_at_us: 1234,
        }
    }

    #[test]
    fn timestamp_ordering_preserves_sequence_payload_and_arrival_metadata() {
        let origin = Instant::now();
        let mut buffer = AudioJitterBuffer::new(48_000);
        buffer.push(packet(10, 2400), origin);
        buffer.push(packet(12, 2880), origin);
        buffer.push(packet(11, 2640), origin + Duration::from_millis(20));
        assert!(buffer.pop(origin + Duration::from_millis(44)).is_none());
        for (offset, sequence) in [(45, 10), (50, 11), (55, 12)] {
            let frame = buffer.pop(origin + Duration::from_millis(offset)).unwrap();
            assert_eq!(frame.header.sequence_number, sequence);
            assert_eq!(frame.header.timestamp, u32::from(sequence) * 240);
            assert_eq!(frame.received_at_us, 1234);
            assert_eq!(&*frame.payload, &[sequence as u8]);
        }
        assert_eq!(buffer.stats.reordered, 1);
    }

    #[test]
    fn wraps_duplicates_and_source_change_remain_bounded() {
        let origin = Instant::now();
        let mut buffer = AudioJitterBuffer::new(48_000);
        buffer.push(packet(65535, u32::MAX - 239), origin);
        buffer.push(packet(1, 240), origin);
        buffer.push(packet(0, 0), origin);
        buffer.push(packet(0, 0), origin);
        for sequence in [65535, 0, 1] {
            assert_eq!(
                buffer
                    .pop(origin + Duration::from_millis(55))
                    .unwrap()
                    .header
                    .sequence_number,
                sequence
            );
        }
        buffer.push(packet(0, 0), origin);
        assert_eq!(buffer.stats.stale, 2);
        let mut replacement = packet(1, 0);
        replacement.header.ssrc = 43.into();
        buffer.push(replacement, origin);
        assert_eq!(buffer.stats.source_resets, 1);
        assert!(buffer.pop(origin + Duration::from_millis(44)).is_none());
        assert_eq!(
            *buffer
                .pop(origin + Duration::from_millis(45))
                .unwrap()
                .header
                .ssrc,
            43
        );
    }

    #[test]
    fn late_bursts_raise_target_in_twenty_millisecond_steps_up_to_ceiling() {
        let origin = Instant::now();
        let mut buffer = AudioJitterBuffer::new(48_000);
        buffer.push(packet(0, 0), origin);
        buffer.pop(origin + Duration::from_millis(45)).unwrap();
        for step in 1..=20 {
            let sequence = step * 2 - 1;
            let timestamp = u32::from(step) * 48_000;
            let late =
                origin + Duration::from_millis(u64::from(step) * 1_000 + buffer.target_ms() + 1);
            buffer.push(packet(sequence, timestamp), late);
            assert_eq!(buffer.target_ms(), (45 + u64::from(step) * 20).min(200));
            buffer.pop(late + Duration::from_millis(20)).unwrap();
            let next = packet(sequence + 1, timestamp + 24_000);
            let timely = origin + Duration::from_millis(u64::from(step) * 1_000 + 500);
            buffer.push(next, timely);
            buffer
                .pop(timely + Duration::from_millis(buffer.target_ms()))
                .unwrap();
        }
        assert_eq!(buffer.target_ms(), 200);
        assert_eq!(buffer.stats.underflows, 20);
    }

    #[test]
    fn clean_network_keeps_the_forty_five_millisecond_floor() {
        let origin = Instant::now();
        let mut buffer = AudioJitterBuffer::new(48_000);
        let mut delivered = 0;
        for tick in 0..=1050_u64 {
            let now = origin + Duration::from_millis(tick);
            if tick <= 1000 && tick % 5 == 0 {
                buffer.push(packet((tick / 5) as u16, tick as u32 * 48), now);
            }
            while let Some(packet) = buffer.pop(now) {
                assert_eq!(tick, u64::from(packet.header.timestamp) / 48 + 45);
                delivered += 1;
            }
            assert_eq!(buffer.target_ms(), 45);
        }
        assert_eq!(delivered, 201);
        assert_eq!(buffer.stats.underflows, 0);
        assert_eq!(buffer.len(), 0);
    }

    #[test]
    fn packet_count_timestamp_span_and_payload_size_are_bounded() {
        let origin = Instant::now();
        let mut buffer = AudioJitterBuffer::new(48_000);
        for sequence in 0..200 {
            buffer.push(packet(sequence, u32::from(sequence) * 120), origin);
            assert!(buffer.len() <= MAX_PACKETS);
        }
        assert!(buffer.stats.overflow > 0);
        buffer.push(packet(200, 48_000), origin);
        assert_eq!(buffer.len(), 1);
        let mut invalid = packet(201, 48_120);
        invalid.payload = Arc::from(vec![0; MAX_PAYLOAD_BYTES + 1]);
        buffer.push(invalid, origin);
        assert_eq!(buffer.stats.invalid, 1);
    }
}
