import { useRef, useState, useEffect, useCallback } from 'react';
import { Modal, Button, Spin, Slider } from 'antd';
import { PlayCircleOutlined, PauseCircleOutlined, ReloadOutlined } from '@ant-design/icons';

function fmt(seconds: number) {
  if (!seconds || !isFinite(seconds)) return '0:00';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

interface Props {
  open: boolean;
  onClose: () => void;
  src: string;
  /** fileId for same-origin waveform fetch via /api/files/:id/stream */
  fileId?: string;
  title?: string;
}

function extractPeaks(buffer: AudioBuffer, numChunks: number): number[] {
  const peaks: number[] = [];
  const channelData = buffer.getChannelData(0);
  const samplesPerChunk = Math.floor(channelData.length / numChunks);
  for (let i = 0; i < numChunks; i++) {
    let max = 0;
    const start = i * samplesPerChunk;
    const end = Math.min(start + samplesPerChunk, channelData.length);
    for (let j = start; j < end; j++) {
      const abs = Math.abs(channelData[j]);
      if (abs > max) max = abs;
    }
    peaks.push(max);
  }
  return peaks;
}

function drawWaveform(
  canvas: HTMLCanvasElement,
  peaks: number[],
  progress: number,
  barGap: number,
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const { width, height } = canvas;
  const mid = height / 2;
  const barWidth = width / peaks.length - barGap;
  if (barWidth <= 0) return;

  ctx.clearRect(0, 0, width, height);

  // Background: full waveform in light gray
  for (let i = 0; i < peaks.length; i++) {
    const x = i * (barWidth + barGap);
    const peakH = Math.max(peaks[i] * mid * 0.92, 1);
    ctx.fillStyle = '#e8e8e8';
    ctx.fillRect(x, mid - peakH, barWidth, peakH * 2);
  }

  // Progress overlay
  const playedEnd = Math.floor(peaks.length * progress);
  for (let i = 0; i < playedEnd; i++) {
    const x = i * (barWidth + barGap);
    const peakH = Math.max(peaks[i] * mid * 0.92, 1);
    ctx.fillStyle = '#1677ff';
    ctx.fillRect(x, mid - peakH, barWidth, peakH * 2);
  }

  // Playhead line
  const posX = progress * width;
  ctx.strokeStyle = '#ff4d4f';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(posX, 2);
  ctx.lineTo(posX, height - 2);
  ctx.stroke();
}

export default function AudioPlayerModal({ open, onClose, src, fileId, title }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const peaksRef = useRef<number[]>([]);
  const durationRef = useRef(0);

  const [phase, setPhase] = useState<'loading' | 'ready' | 'error'>('loading');
  const [errorMsg, setErrorMsg] = useState('');
  const [playing, setPlaying] = useState(false);
  const [duration, setDuration] = useState(0);
  const [current, setCurrent] = useState(0);
  const [meta, setMeta] = useState<{ sampleRate: number; channels: number } | null>(null);
  const [hasWaveform, setHasWaveform] = useState(false);

  // Waveform URL: always use same-origin streaming endpoint when fileId is available
  const waveformUrl = fileId ? `/api/files/${fileId}/stream` : src;

  // -- load on open/src change --
  useEffect(() => {
    if (!open || !src) return;

    // Reset
    setPhase('loading');
    setErrorMsg('');
    setPlaying(false);
    setDuration(0);
    setCurrent(0);
    setMeta(null);
    setHasWaveform(false);
    durationRef.current = 0;
    peaksRef.current = [];
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
      audioRef.current = null;
    }

    let cancelled = false;

    // 1. <audio> element for playback — src can be any URL (cross-origin OK)
    const audio = new Audio(src);
    audio.preload = 'auto';
    audioRef.current = audio;

    audio.addEventListener('loadedmetadata', () => {
      if (cancelled) return;
      const d = audio.duration;
      if (d && isFinite(d)) {
        durationRef.current = d;
        setDuration(d);
      }
    });
    audio.addEventListener('timeupdate', () => {
      if (cancelled) return;
      const d = audio.duration;
      if (d && isFinite(d) && d !== durationRef.current) {
        durationRef.current = d;
        setDuration(d);
      }
      setCurrent(audio.currentTime);
      if (hasWaveform) redraw();
    });
    audio.addEventListener('ended', () => {
      if (cancelled) return;
      setPlaying(false);
      setCurrent(0);
      if (hasWaveform) { setTimeout(() => redraw(), 50); }
    });
    audio.addEventListener('error', () => {
      if (cancelled) return;
      setErrorMsg('音频加载失败，请检查文件是否存在');
      setPhase('error');
    });

    // Show UI once audio is playable, then load waveform in background
    const onCanPlay = () => {
      if (cancelled) return;
      const d = audio.duration;
      if (d && isFinite(d)) {
        durationRef.current = d;
        setDuration(d);
      }
      setPhase('ready');
      loadWaveform();
    };
    audio.addEventListener('canplay', onCanPlay, { once: true });

    // Fallback: if canplay doesn't fire within 3s, show UI anyway
    const fallbackTimer = setTimeout(() => {
      if (!cancelled && phase === 'loading') {
        setPhase('ready');
        loadWaveform();
      }
    }, 3000);

    return () => {
      cancelled = true;
      clearTimeout(fallbackTimer);
      audio.removeEventListener('canplay', onCanPlay);
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current.src = '';
        audioRef.current = null;
      }
    };
  }, [open, src]);

  // 2. Waveform loading — uses same-origin URL via fileId, not cross-origin src
  async function loadWaveform() {
    try {
      const res = await fetch(waveformUrl);
      if (!res.ok) return;
      const arrayBuffer = await res.arrayBuffer();

      const ctx = new AudioContext();
      const buffer = await ctx.decodeAudioData(arrayBuffer.slice(0));
      ctx.close();

      const numChunks = Math.min(Math.max(Math.floor(buffer.duration * 40), 200), 1200);
      peaksRef.current = extractPeaks(buffer, numChunks);
      setMeta({ sampleRate: buffer.sampleRate, channels: buffer.numberOfChannels });
      setHasWaveform(true);

      if (buffer.duration && isFinite(buffer.duration)) {
        durationRef.current = buffer.duration;
        setDuration(buffer.duration);
      }

      setTimeout(() => redraw(), 50);
    } catch {
      // Waveform loading failed — playback still works
    }
  }

  function redraw() {
    const canvas = canvasRef.current;
    if (!canvas || peaksRef.current.length === 0) return;
    const progress = durationRef.current > 0
      ? (audioRef.current?.currentTime || 0) / durationRef.current
      : 0;
    drawWaveform(canvas, peaksRef.current, progress, 1);
  }

  useEffect(() => {
    if (!open || !hasWaveform) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const obs = new ResizeObserver(() => redraw());
    obs.observe(canvas);
    return () => obs.disconnect();
  }, [open, hasWaveform]);

  const togglePlay = useCallback(() => {
    const a = audioRef.current;
    if (!a) return;
    if (a.paused || a.ended) {
      if (a.ended) { a.currentTime = 0; }
      a.play().then(() => setPlaying(true)).catch(() => setErrorMsg('播放失败'));
    } else {
      a.pause();
      setPlaying(false);
    }
  }, []);

  const handleSeek = useCallback((v: number) => {
    const a = audioRef.current;
    if (!a) return;
    a.currentTime = v;
    setCurrent(v);
  }, []);

  const handleWaveformClick = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    const a = audioRef.current;
    if (!canvas || !a || !durationRef.current) return;
    const rect = canvas.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    const time = ratio * durationRef.current;
    a.currentTime = time;
    setCurrent(time);
    redraw();
  }, []);

  const handleClose = () => {
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
      audioRef.current = null;
    }
    setPlaying(false);
    onClose();
  };

  return (
    <Modal
      title={title || '音频播放'}
      open={open}
      onCancel={handleClose}
      footer={null}
      width={600}
      destroyOnClose
    >
      {phase === 'loading' && (
        <div style={{ textAlign: 'center', padding: 56 }}>
          <Spin size="large" />
          <div style={{ marginTop: 16, color: '#999' }}>正在加载音频...</div>
        </div>
      )}

      {phase === 'error' && (
        <div style={{ textAlign: 'center', padding: 48 }}>
          <div style={{ color: '#ff4d4f', fontSize: 14, marginBottom: 16 }}>{errorMsg}</div>
          <Button icon={<ReloadOutlined />} onClick={handleClose}>关闭</Button>
        </div>
      )}

      {phase === 'ready' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, alignItems: 'center' }}>
          {/* Waveform canvas */}
          {hasWaveform ? (
            <canvas
              ref={canvasRef}
              onClick={handleWaveformClick}
              style={{
                width: '100%',
                height: 130,
                borderRadius: 6,
                background: '#fafafa',
                cursor: 'pointer',
                border: '1px solid #f0f0f0',
              }}
            />
          ) : (
            <div style={{
              width: '100%', height: 80, borderRadius: 6,
              background: '#fafafa', border: '1px solid #f0f0f0',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#bbb', fontSize: 13,
            }}>
              波形加载中...
            </div>
          )}

          {/* Time + seek bar */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', fontSize: 13, color: '#888' }}>
            <span style={{ fontVariantNumeric: 'tabular-nums', minWidth: 42 }}>{fmt(current)}</span>
            <Slider
              style={{ flex: 1, margin: 0 }}
              min={0}
              max={duration || 1}
              value={current}
              onChange={handleSeek}
              tooltip={{ formatter: (v) => fmt(v ?? 0) }}
            />
            <span style={{ fontVariantNumeric: 'tabular-nums', minWidth: 42, textAlign: 'right' }}>{fmt(duration)}</span>
          </div>

          {/* Play/Pause */}
          <Button
            type="primary"
            shape="circle"
            size="large"
            icon={playing ? <PauseCircleOutlined style={{ fontSize: 26 }} /> : <PlayCircleOutlined style={{ fontSize: 26 }} />}
            onClick={togglePlay}
            style={{ width: 52, height: 52 }}
          />

          {/* Metadata */}
          {meta && (
            <div style={{
              display: 'flex', gap: 28, fontSize: 12, color: '#999',
              padding: '8px 20px', background: '#fafafa', borderRadius: 6,
              justifyContent: 'center', flexWrap: 'wrap', width: '100%',
            }}>
              <span>采样率 <b style={{ color: '#555' }}>{meta.sampleRate} Hz</b></span>
              <span>声道 <b style={{ color: '#555' }}>{meta.channels === 1 ? '单声道' : meta.channels === 2 ? '立体声' : `${meta.channels}声道`}</b></span>
              <span>时长 <b style={{ color: '#555' }}>{fmt(duration)}</b></span>
            </div>
          )}
        </div>
      )}
    </Modal>
  );
}
