import { useRef, useState, useEffect, useCallback } from 'react';
import { Modal, Button, Spin } from 'antd';
import { PlayCircleOutlined, PauseCircleOutlined, ReloadOutlined } from '@ant-design/icons';

function fmt(seconds: number) {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

interface Props {
  open: boolean;
  onClose: () => void;
  src: string;
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

  // Progress overlay: played portion in brand blue
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

export default function AudioPlayerModal({ open, onClose, src, title }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const peaksRef = useRef<number[]>([]);
  const progressRef = useRef(0);
  const durationRef = useRef(0);
  const objectUrlRef = useRef<string | null>(null);

  const [phase, setPhase] = useState<'loading' | 'ready' | 'error'>('loading');
  const [errorMsg, setErrorMsg] = useState('');
  const [playing, setPlaying] = useState(false);
  const [duration, setDuration] = useState(0);
  const [current, setCurrent] = useState(0);
  const [meta, setMeta] = useState<{ sampleRate: number; channels: number } | null>(null);

  // -- load audio on open/src change --
  useEffect(() => {
    if (!open || !src) return;

    // Reset
    setPhase('loading');
    setErrorMsg('');
    setPlaying(false);
    setDuration(0);
    setCurrent(0);
    setMeta(null);
    progressRef.current = 0;
    durationRef.current = 0;
    peaksRef.current = [];
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
    }
    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    }

    let cancelled = false;

    (async () => {
      try {
        // 1. Download once
        const res = await fetch(src);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const arrayBuffer = await res.arrayBuffer();

        // 2. Create blob URL for playback (avoids double-download)
        const mime = res.headers.get('content-type') || 'audio/wav';
        const blob = new Blob([arrayBuffer], { type: mime });
        objectUrlRef.current = URL.createObjectURL(blob);

        // 3. Decode waveform (slice because decodeAudioData detaches the buffer)
        const ctx = new AudioContext();
        const buffer = await ctx.decodeAudioData(arrayBuffer.slice(0));
        ctx.close(); // free-up — not needed for playback

        const numChunks = Math.min(Math.max(Math.floor(buffer.duration * 40), 200), 1200);
        const peaks = extractPeaks(buffer, numChunks);

        if (cancelled) return;

        peaksRef.current = peaks;
        setMeta({ sampleRate: buffer.sampleRate, channels: buffer.numberOfChannels });

        // 4. Playback audio element
        const audio = new Audio(objectUrlRef.current);
        audio.preload = 'auto';
        audioRef.current = audio;

        audio.addEventListener('loadedmetadata', () => {
          durationRef.current = audio.duration || buffer.duration;
          setDuration(durationRef.current);
          redraw();
        });
        audio.addEventListener('timeupdate', () => {
          progressRef.current = durationRef.current > 0 ? audio.currentTime / durationRef.current : 0;
          durationRef.current = audio.duration || durationRef.current;
          setCurrent(audio.currentTime);
          setDuration(durationRef.current);
          redraw();
        });
        audio.addEventListener('ended', () => {
          setPlaying(false);
          progressRef.current = 0;
          setCurrent(0);
          redraw();
        });
        audio.addEventListener('error', () => {
          setErrorMsg('播放失败');
        });

        setDuration(buffer.duration);
        durationRef.current = buffer.duration;
        setPhase('ready');
        // Draw initial waveform
        setTimeout(() => redraw(), 50);
      } catch (e: any) {
        if (cancelled) return;
        setErrorMsg(e?.message || '音频加载失败');
        setPhase('error');
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [open, src]);

  function redraw() {
    const canvas = canvasRef.current;
    if (!canvas || peaksRef.current.length === 0) return;
    drawWaveform(canvas, peaksRef.current, progressRef.current, 1);
  }

  // Redraw on canvas resize
  useEffect(() => {
    if (!open || phase !== 'ready') return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const obs = new ResizeObserver(() => redraw());
    obs.observe(canvas);
    return () => obs.disconnect();
  }, [open, phase]);

  // -- controls --
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

  const handleWaveformClick = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    const a = audioRef.current;
    if (!canvas || !a) return;
    const rect = canvas.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    a.currentTime = ratio * durationRef.current;
    progressRef.current = ratio;
    setCurrent(a.currentTime);
    redraw();
  }, []);

  const handleClose = () => {
    if (audioRef.current) {
      audioRef.current.pause();
    }
    setPlaying(false);
    onClose();
  };

  const handleRetry = () => {
    setPhase('loading');
    setErrorMsg('');
    // Trigger re-fetch by changing src-dependent effect via a temp key
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
    }
    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    }
    // Re-trigger the load effect
    setPhase('loading');
    setTimeout(() => {
      // Force re-run of the effect by closing and re-opening
      // We use a key trick: just re-invoke the fetch manually
      const doLoad = async () => {
        try {
          const res = await fetch(src);
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          const arrayBuffer = await res.arrayBuffer();
          const mime = res.headers.get('content-type') || 'audio/wav';
          const blob = new Blob([arrayBuffer], { type: mime });
          objectUrlRef.current = URL.createObjectURL(blob);

          const ctx = new AudioContext();
          const buffer = await ctx.decodeAudioData(arrayBuffer.slice(0));
          ctx.close();

          const numChunks = Math.min(Math.max(Math.floor(buffer.duration * 40), 200), 1200);
          const peaks = extractPeaks(buffer, numChunks);

          peaksRef.current = peaks;
          setMeta({ sampleRate: buffer.sampleRate, channels: buffer.numberOfChannels });

          const audio = new Audio(objectUrlRef.current);
          audio.preload = 'auto';
          audioRef.current = audio;

          audio.addEventListener('loadedmetadata', () => {
            durationRef.current = audio.duration || buffer.duration;
            setDuration(durationRef.current);
            redraw();
          });
          audio.addEventListener('timeupdate', () => {
            progressRef.current = durationRef.current > 0 ? audio.currentTime / durationRef.current : 0;
            durationRef.current = audio.duration || durationRef.current;
            setCurrent(audio.currentTime);
            setDuration(durationRef.current);
            redraw();
          });
          audio.addEventListener('ended', () => {
            setPlaying(false);
            progressRef.current = 0;
            setCurrent(0);
            redraw();
          });
          audio.addEventListener('error', () => setErrorMsg('播放失败'));

          setDuration(buffer.duration);
          durationRef.current = buffer.duration;
          setPhase('ready');
          setTimeout(() => redraw(), 50);
        } catch (e: any) {
          setErrorMsg(e?.message || '音频加载失败');
          setPhase('error');
        }
      };
      doLoad();
    }, 0);
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
          <div style={{ marginTop: 16, color: '#999' }}>正在解析音频...</div>
        </div>
      )}

      {phase === 'error' && (
        <div style={{ textAlign: 'center', padding: 48 }}>
          <div style={{ color: '#ff4d4f', fontSize: 14, marginBottom: 16 }}>{errorMsg}</div>
          <Button icon={<ReloadOutlined />} onClick={handleRetry}>重试</Button>
        </div>
      )}

      {phase === 'ready' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, alignItems: 'center' }}>
          {/* Waveform canvas */}
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

          {/* Time + thin progress bar */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', fontSize: 13, color: '#888' }}>
            <span style={{ fontVariantNumeric: 'tabular-nums', minWidth: 42 }}>{fmt(current)}</span>
            <div style={{ flex: 1, height: 3, background: '#f0f0f0', borderRadius: 2 }}>
              <div style={{
                height: '100%',
                width: `${duration > 0 ? (current / duration) * 100 : 0}%`,
                background: '#1677ff',
                borderRadius: 2,
                transition: 'width 80ms linear',
              }} />
            </div>
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
