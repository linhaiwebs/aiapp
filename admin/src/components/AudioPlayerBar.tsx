import { useRef, useState, useEffect, useCallback } from 'react';
import { Button, Slider } from 'antd';
import { PlayCircleOutlined, PauseCircleOutlined } from '@ant-design/icons';

function fmt(seconds: number) {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

interface Props {
  src: string;
  /** show only play/pause button (compact mode for table cells) */
  compact?: boolean;
}

export default function AudioPlayerBar({ src, compact }: Props) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [playing, setPlaying] = useState(false);
  const [duration, setDuration] = useState(0);
  const [current, setCurrent] = useState(0);
  const [seeking, setSeeking] = useState(false);

  useEffect(() => {
    const audio = new Audio(src);
    audioRef.current = audio;
    audio.preload = 'metadata';

    const onLoaded = () => setDuration(audio.duration || 0);
    const onTime = () => { if (!seeking) setCurrent(audio.currentTime); };
    const onEnd = () => { setPlaying(false); setCurrent(0); };
    const onErr = () => { setPlaying(false); };

    audio.addEventListener('loadedmetadata', onLoaded);
    audio.addEventListener('timeupdate', onTime);
    audio.addEventListener('ended', onEnd);
    audio.addEventListener('error', onErr);

    return () => {
      audio.removeEventListener('loadedmetadata', onLoaded);
      audio.removeEventListener('timeupdate', onTime);
      audio.removeEventListener('ended', onEnd);
      audio.removeEventListener('error', onErr);
      audio.pause();
      audio.src = '';
    };
  }, [src]);

  const togglePlay = useCallback(() => {
    const a = audioRef.current;
    if (!a) return;
    if (a.paused || a.ended) {
      if (a.ended) { a.currentTime = 0; setCurrent(0); }
      a.play().then(() => setPlaying(true)).catch(() => {});
    } else {
      a.pause();
      setPlaying(false);
    }
  }, []);

  const handleSeek = useCallback((v: number) => {
    const a = audioRef.current;
    if (!a || !duration) return;
    setCurrent(v);
    setSeeking(true);
    a.currentTime = v;
    // defer releasing the flag so timeupdate doesn't fight
    setTimeout(() => setSeeking(false), 200);
  }, [duration]);

  if (compact) {
    return (
      <Button
        type="link"
        size="small"
        icon={playing ? <PauseCircleOutlined /> : <PlayCircleOutlined />}
        onClick={togglePlay}
      />
    );
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%', minWidth: 220 }}>
      <Button
        type="text"
        size="small"
        icon={playing ? <PauseCircleOutlined style={{ fontSize: 20 }} /> : <PlayCircleOutlined style={{ fontSize: 20 }} />}
        onClick={togglePlay}
      />
      <span style={{ fontSize: 12, fontVariantNumeric: 'tabular-nums', minWidth: 32, color: '#666' }}>
        {fmt(current)}
      </span>
      <Slider
        style={{ flex: 1, margin: 0 }}
        min={0}
        max={duration || 1}
        value={current}
        onChange={handleSeek}
        tooltip={{ formatter: (v) => fmt(v ?? 0) }}
      />
      <span style={{ fontSize: 12, fontVariantNumeric: 'tabular-nums', minWidth: 32, color: '#666' }}>
        {fmt(duration)}
      </span>
    </div>
  );
}
