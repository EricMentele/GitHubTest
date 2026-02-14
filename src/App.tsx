import { useRef, useState, useEffect, useCallback } from 'react';
import { useOdyssey } from '@odysseyml/odyssey/react';
import type { Recording } from '@odysseyml/odyssey/react';

type AppPhase = 'setup' | 'connected' | 'streaming';

export default function App() {
  const [apiKey, setApiKey] = useState(() => localStorage.getItem('odyssey_api_key') || '');
  const [phase, setPhase] = useState<AppPhase>('setup');
  const [prompt, setPrompt] = useState('');
  const [interactPrompt, setInteractPrompt] = useState('');
  const [portrait, setPortrait] = useState(true);
  const [image, setImage] = useState<File | null>(null);
  const [streamId, setStreamId] = useState<string | null>(null);
  const [recording, setRecording] = useState<Recording | null>(null);
  const [log, setLog] = useState<string[]>([]);
  const [loading, setLoading] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  const videoRef = useRef<HTMLVideoElement>(null);
  const logEndRef = useRef<HTMLDivElement>(null);

  const addLog = useCallback((msg: string) => {
    setLog((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]);
  }, []);

  const odyssey = useOdyssey({
    apiKey,
    handlers: {
      onConnected: (stream) => {
        addLog('Connected — media stream ready');
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
        }
      },
      onDisconnected: () => {
        addLog('Disconnected');
        setPhase('setup');
        setStreamId(null);
      },
      onStreamStarted: (id) => {
        addLog(`Stream started: ${id}`);
        setStreamId(id);
        setPhase('streaming');
        setLoading('');
      },
      onStreamEnded: () => {
        addLog('Stream ended');
        setPhase('connected');
        setLoading('');
      },
      onInteractAcknowledged: (p) => {
        addLog(`Interaction acknowledged: "${p}"`);
        setLoading('');
      },
      onStreamError: (reason, message) => {
        addLog(`Stream error: ${reason} — ${message}`);
        setLoading('');
      },
      onError: (error, fatal) => {
        addLog(`${fatal ? 'FATAL ' : ''}Error: ${error.message}`);
        setErrorMsg(error.message);
        setLoading('');
        if (fatal) {
          setPhase('setup');
          setStreamId(null);
        }
      },
    },
  });

  // Auto-scroll log
  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [log]);

  // Attach stream to video when mediaStream changes
  useEffect(() => {
    if (videoRef.current && odyssey.mediaStream) {
      videoRef.current.srcObject = odyssey.mediaStream;
    }
  }, [odyssey.mediaStream]);

  const handleConnect = async () => {
    if (!apiKey.trim()) {
      setErrorMsg('Please enter an API key');
      return;
    }
    localStorage.setItem('odyssey_api_key', apiKey);
    setErrorMsg('');
    setLoading('Connecting...');
    addLog('Connecting to Odyssey...');
    try {
      await odyssey.connect();
      setPhase('connected');
      addLog('Ready to start a stream');
    } catch (err: any) {
      addLog(`Connection failed: ${err.message}`);
      setErrorMsg(err.message);
    }
    setLoading('');
  };

  const handleStartStream = async () => {
    if (!prompt.trim()) {
      setErrorMsg('Please enter a prompt');
      return;
    }
    setErrorMsg('');
    setLoading('Starting stream...');
    setRecording(null);
    addLog(`Starting stream: "${prompt}" (${portrait ? 'portrait' : 'landscape'})`);
    try {
      await odyssey.startStream({
        prompt,
        portrait,
        ...(image ? { image } : {}),
      });
    } catch (err: any) {
      addLog(`Start stream failed: ${err.message}`);
      setErrorMsg(err.message);
      setLoading('');
    }
  };

  const handleInteract = async () => {
    if (!interactPrompt.trim()) return;
    setErrorMsg('');
    setLoading('Sending interaction...');
    addLog(`Interacting: "${interactPrompt}"`);
    const p = interactPrompt;
    setInteractPrompt('');
    try {
      await odyssey.interact({ prompt: p });
    } catch (err: any) {
      addLog(`Interact failed: ${err.message}`);
      setErrorMsg(err.message);
      setLoading('');
    }
  };

  const handleEndStream = async () => {
    setLoading('Ending stream...');
    addLog('Ending stream...');
    try {
      await odyssey.endStream();
    } catch (err: any) {
      addLog(`End stream failed: ${err.message}`);
      setLoading('');
    }
  };

  const handleGetRecording = async () => {
    if (!streamId) return;
    setLoading('Fetching recording...');
    addLog(`Fetching recording for stream ${streamId}...`);
    try {
      const rec = await odyssey.getRecording(streamId);
      setRecording(rec);
      addLog(
        rec.video_url
          ? `Recording ready — ${rec.duration_seconds?.toFixed(1)}s, ${rec.frame_count} frames`
          : 'Recording not yet available'
      );
    } catch (err: any) {
      addLog(`Get recording failed: ${err.message}`);
      setErrorMsg(err.message);
    }
    setLoading('');
  };

  const handleDisconnect = () => {
    odyssey.disconnect();
    setPhase('setup');
    setStreamId(null);
    setRecording(null);
    addLog('Disconnected');
  };

  const handleKeyDown = (e: React.KeyboardEvent, action: () => void) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      action();
    }
  };

  return (
    <div className="app">
      <header>
        <h1>Odyssey Video Generator</h1>
        <div className="status-bar">
          <span className={`status-dot ${odyssey.status}`} />
          <span className="status-text">{odyssey.status}</span>
          {odyssey.sessionId && (
            <span className="session-id">Session: {odyssey.sessionId.slice(0, 8)}...</span>
          )}
        </div>
      </header>

      <div className="main-layout">
        {/* Video Panel */}
        <div className="video-panel">
          <div className={`video-container ${portrait ? 'portrait' : 'landscape'}`}>
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
            />
            {phase === 'setup' && (
              <div className="video-placeholder">
                Enter your API key and connect to get started
              </div>
            )}
            {phase === 'connected' && !odyssey.mediaStream && (
              <div className="video-placeholder">
                Connected — enter a prompt and start streaming
              </div>
            )}
          </div>

          {/* Recording Result */}
          {recording?.video_url && (
            <div className="recording-card">
              <h3>Recording</h3>
              <div className="recording-meta">
                {recording.duration_seconds && <span>{recording.duration_seconds.toFixed(1)}s</span>}
                {recording.frame_count && <span>{recording.frame_count} frames</span>}
              </div>
              <div className="recording-actions">
                <a href={recording.video_url} target="_blank" rel="noopener noreferrer" className="btn btn-primary">
                  Download Video
                </a>
                {recording.thumbnail_url && (
                  <a href={recording.thumbnail_url} target="_blank" rel="noopener noreferrer" className="btn btn-secondary">
                    Thumbnail
                  </a>
                )}
                {recording.preview_url && (
                  <a href={recording.preview_url} target="_blank" rel="noopener noreferrer" className="btn btn-secondary">
                    Preview
                  </a>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Controls Panel */}
        <div className="controls-panel">
          {/* Setup / API Key */}
          {phase === 'setup' && (
            <section className="control-section">
              <h2>Connect</h2>
              <label>
                API Key
                <input
                  type="password"
                  value={apiKey}
                  onChange={(e) => setApiKey(e.target.value)}
                  onKeyDown={(e) => handleKeyDown(e, handleConnect)}
                  placeholder="ody_..."
                />
              </label>
              <button className="btn btn-primary" onClick={handleConnect} disabled={!!loading}>
                {loading || 'Connect'}
              </button>
            </section>
          )}

          {/* Stream Controls */}
          {phase === 'connected' && (
            <section className="control-section">
              <h2>New Stream</h2>
              <label>
                Prompt
                <textarea
                  value={prompt}
                  onChange={(e) => setPrompt(e.target.value)}
                  onKeyDown={(e) => handleKeyDown(e, handleStartStream)}
                  placeholder="A cat sitting on a windowsill, golden hour lighting"
                  rows={3}
                />
              </label>
              <div className="option-row">
                <label className="toggle-label">
                  <input
                    type="checkbox"
                    checked={portrait}
                    onChange={(e) => setPortrait(e.target.checked)}
                  />
                  Portrait mode
                </label>
              </div>
              <label>
                Image (optional)
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => setImage(e.target.files?.[0] || null)}
                />
              </label>
              <button className="btn btn-primary" onClick={handleStartStream} disabled={!!loading}>
                {loading || 'Start Stream'}
              </button>

              {streamId && (
                <button className="btn btn-secondary" onClick={handleGetRecording} disabled={!!loading}>
                  Get Last Recording
                </button>
              )}

              <button className="btn btn-danger" onClick={handleDisconnect}>
                Disconnect
              </button>
            </section>
          )}

          {/* Streaming Controls */}
          {phase === 'streaming' && (
            <section className="control-section">
              <h2>Live Stream</h2>
              <label>
                Interact
                <textarea
                  value={interactPrompt}
                  onChange={(e) => setInteractPrompt(e.target.value)}
                  onKeyDown={(e) => handleKeyDown(e, handleInteract)}
                  placeholder="Change the lighting to dramatic blue..."
                  rows={2}
                />
              </label>
              <button className="btn btn-primary" onClick={handleInteract} disabled={!!loading || !interactPrompt.trim()}>
                {loading === 'Sending interaction...' ? loading : 'Send Interaction'}
              </button>
              <button className="btn btn-danger" onClick={handleEndStream} disabled={!!loading}>
                End Stream
              </button>
            </section>
          )}

          {/* Error Display */}
          {errorMsg && (
            <div className="error-banner" onClick={() => setErrorMsg('')}>
              {errorMsg}
            </div>
          )}

          {/* Activity Log */}
          <section className="log-section">
            <h2>Activity Log</h2>
            <div className="log-container">
              {log.length === 0 && <div className="log-empty">No activity yet</div>}
              {log.map((entry, i) => (
                <div key={i} className="log-entry">{entry}</div>
              ))}
              <div ref={logEndRef} />
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
