/**
 * TravelBuddy — Offline In-Browser Reel Video Generator
 * ======================================================
 * • 100% offline — zero network calls, no CDN, no server
 * • Accepts File objects (from drag-drop or file picker) — any image format
 *   the browser can decode: JPG, PNG, WEBP, GIF, BMP, AVIF, SVG, HEIC (Safari/iOS)
 *   RAW files (NEF, CR2, ARW, DNG) render as a placeholder card since browsers
 *   cannot natively decode RAW — that is a browser limitation, not the app's.
 * • Up to 100 photos · 50 MB per photo
 * • Target: exactly 60 seconds of video at 30 fps (1 800 frames total)
 *   Each photo gets floor(1800 / photoCount) frames, remainder distributed to first slides.
 * • Ken Burns: smooth zoom 1.00 → 1.08 per slide
 * • Cross-fade: 15-frame alpha transition between slides
 * • Caption overlay: bottom-third gradient + word-wrapped text
 * • Output: WebM (VP9) preferred; MP4 (H.264) if browser supports it
 */

'use strict';

// ─── Constants ────────────────────────────────────────────────────────────────
const VG = Object.freeze({
    WIDTH: 720,
    HEIGHT: 1280,
    FPS: 30,
    DURATION_S: 60,           // 1 minute
    TOTAL_FRAMES: 30 * 60,      // 1 800
    FADE_FRAMES: 15,           // 0.5-second cross-fade
    BITRATE: 5_000_000,    // 5 Mbps — good quality for 720×1280
    MAX_FILES: 100,
    MAX_MB: 50,
    // All image formats browsers can decode natively (File objects)
    ACCEPTED_TYPES: new Set([
        'image/jpeg', 'image/jpg', 'image/png', 'image/webp',
        'image/gif', 'image/bmp', 'image/avif', 'image/svg+xml',
        'image/heic', 'image/heif', 'image/tiff',
    ]),
    RAW_EXTS: new Set(['nef', 'cr2', 'arw', 'dng', 'raw', 'raf', 'orf', 'rw2', 'pef']),
});

// ─── Utility: load any File/URL into HTMLImageElement ─────────────────────────
function _loadImageFile(file) {
    return new Promise((resolve, reject) => {
        if (file instanceof File) {
            const ext = file.name.split('.').pop().toLowerCase();
            // RAW — browser cannot decode; create a text placeholder canvas instead
            if (VG.RAW_EXTS.has(ext)) {
                const c = document.createElement('canvas');
                c.width = VG.WIDTH; c.height = VG.HEIGHT;
                const cx = c.getContext('2d');
                cx.fillStyle = '#0f172a';
                cx.fillRect(0, 0, VG.WIDTH, VG.HEIGHT);
                cx.fillStyle = '#38bdf8';
                cx.font = 'bold 80px Inter, sans-serif';
                cx.textAlign = 'center';
                cx.fillText('RAW', VG.WIDTH / 2, VG.HEIGHT / 2 - 30);
                cx.fillStyle = '#94a3b8';
                cx.font = '40px Inter, sans-serif';
                cx.fillText(file.name, VG.WIDTH / 2, VG.HEIGHT / 2 + 40);
                // Return canvas as image
                const img = new Image();
                img.onload = () => resolve(img);
                img.src = c.toDataURL();
                return;
            }
            const url = URL.createObjectURL(file);
            const img = new Image();
            img.onload = () => { URL.revokeObjectURL(url); resolve(img); };
            img.onerror = () => { URL.revokeObjectURL(url); reject(new Error(`Cannot decode: ${file.name}`)); };
            img.src = url;
        } else {
            // Plain URL string (for backend refined paths)
            const img = new Image();
            img.crossOrigin = 'anonymous';
            img.onload = () => resolve(img);
            img.onerror = () => reject(new Error(`Cannot load URL: ${file}`));
            img.src = file;
        }
    });
}

// ─── Draw a single frame onto ctx ─────────────────────────────────────────────
function _drawFrame(ctx, img, caption, slideProgress, alpha) {
    const W = VG.WIDTH, H = VG.HEIGHT;

    ctx.save();
    ctx.globalAlpha = Math.max(0, Math.min(1, alpha));

    // ── Ken Burns zoom ──
    const scale = 1.0 + 0.08 * slideProgress;
    const ratio = Math.min(W / img.width, H / img.height) * scale;
    const dx = (W - img.width * ratio) / 2;
    const dy = (H - img.height * ratio) / 2;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, W, H);
    ctx.drawImage(img, dx, dy, img.width * ratio, img.height * ratio);

    // ── Bottom gradient for caption readability ──
    if (caption) {
        const grad = ctx.createLinearGradient(0, H * 0.55, 0, H);
        grad.addColorStop(0, 'rgba(0,0,0,0)');
        grad.addColorStop(1, 'rgba(0,0,0,0.80)');
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, W, H);

        // ── Caption text ──
        ctx.globalAlpha = alpha;
        ctx.fillStyle = '#ffffff';
        ctx.textAlign = 'center';
        ctx.shadowColor = 'rgba(0,0,0,0.9)';
        ctx.shadowBlur = 16;
        const fontSize = Math.round(W * 0.046);
        ctx.font = `700 ${fontSize}px Inter, system-ui, sans-serif`;

        // Word-wrap
        const maxW = W * 0.82;
        const words = caption.split(' ');
        const lines = [];
        let line = '';
        for (const w of words) {
            const test = line ? line + ' ' + w : w;
            if (ctx.measureText(test).width > maxW && line) { lines.push(line); line = w; }
            else line = test;
        }
        if (line) lines.push(line);

        const lineH = fontSize * 1.35;
        const totalH = lines.length * lineH;
        const startY = H - 90 - totalH;
        lines.forEach((l, i) => ctx.fillText(l, W / 2, startY + i * lineH));

        ctx.shadowBlur = 0;
    }

    ctx.restore();
}

// ─── Main: generate video blob from files (or URLs) + captions ────────────────
/**
 * @param {Array<File|string>}  sources   — File objects or URL strings
 * @param {string[]}            captions  — one per photo (can be shorter)
 * @param {function}            onProgress— (message: string, pct: number) => void
 * @returns {Promise<Blob>}
 */
async function generateReelVideo(sources, captions = [], onProgress = () => { }) {
    if (!sources || sources.length === 0) throw new Error('No images provided.');

    // ── 1. Clamp to 100 ──
    const clampedSources = sources.slice(0, VG.MAX_FILES);
    const N = clampedSources.length;

    // ── 2. Set up canvas + MediaRecorder ──
    const canvas = document.createElement('canvas');
    canvas.width = VG.WIDTH;
    canvas.height = VG.HEIGHT;
    const ctx = canvas.getContext('2d', { alpha: false, desynchronized: true });

    // Pick best video format (offline, no codec downloads)
    const mimeType = (() => {
        const candidates = [
            'video/mp4;codecs=avc1.42E01E',
            'video/mp4;codecs=avc1',
            'video/webm;codecs=vp9',
            'video/webm;codecs=vp8',
            'video/webm',
        ];
        for (const m of candidates) {
            if (typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported(m)) return m;
        }
        return 'video/webm';
    })();

    const chunks = [];
    const stream = canvas.captureStream(VG.FPS);
    const recorder = new MediaRecorder(stream, {
        mimeType,
        videoBitsPerSecond: VG.BITRATE,
    });
    recorder.ondataavailable = (e) => { if (e.data && e.data.size > 0) chunks.push(e.data); };

    // ── 3. Pre-load all images ──
    onProgress('Loading images…', 2);
    const imgs = [];
    for (let i = 0; i < clampedSources.length; i++) {
        try {
            imgs.push(await _loadImageFile(clampedSources[i]));
        } catch (e) {
            console.warn('[VG] Skipped:', e.message);
            // Create a black placeholder so frame count stays correct
            const c2 = document.createElement('canvas');
            c2.width = VG.WIDTH; c2.height = VG.HEIGHT;
            const cx2 = c2.getContext('2d');
            cx2.fillStyle = '#1e293b';
            cx2.fillRect(0, 0, VG.WIDTH, VG.HEIGHT);
            cx2.fillStyle = '#64748b';
            cx2.font = 'bold 36px Inter, sans-serif';
            cx2.textAlign = 'center';
            cx2.fillText('⚠ Image Load Failed', VG.WIDTH / 2, VG.HEIGHT / 2);
            cx2.font = '24px Inter, sans-serif';
            cx2.fillText(clampedSources[i].name || 'Unknown File', VG.WIDTH / 2, VG.HEIGHT / 2 + 50);
            const img2 = new Image();
            await new Promise(r => { img2.onload = r; img2.src = c2.toDataURL(); });
            imgs.push(img2);
        }
        onProgress(`Loading image ${i + 1}/${N}…`, 2 + Math.round((i / N) * 8));
    }

    // ── 4. Compute per-slide frame budget (total = 1 800 frames = 60 seconds) ──
    const baseFrames = Math.floor(VG.TOTAL_FRAMES / N);
    const extraFrames = VG.TOTAL_FRAMES - baseFrames * N; // distribute to first slides
    const slideFrames = Array.from({ length: N }, (_, i) => baseFrames + (i < extraFrames ? 1 : 0));

    onProgress('Starting encoder…', 10);
    recorder.start(200); // flush every 200 ms

    // ── 5. Render frames ──────────────────────────────────────────────────────
    // Use setTimeout-based loop: yields to browser every frame so the tab stays
    // responsive and MediaRecorder can collect chunks.
    // Frame delay = 1000/FPS ms ≈ 33 ms — actual rate is best-effort in browsers.
    let globalFrame = 0;
    const MS_PER_FRAME = Math.round(1000 / VG.FPS);

    for (let slideIdx = 0; slideIdx < N; slideIdx++) {
        const img = imgs[slideIdx];
        const cap = captions[slideIdx] || '';
        const total = slideFrames[slideIdx];
        const nextImg = imgs[(slideIdx + 1) % N];

        for (let f = 0; f < total; f++) {
            const progress = f / total;

            // ── Fade alpha (cross-fade at end of each slide) ──
            let alpha = 1;
            if (f > total - VG.FADE_FRAMES) {
                // Fade out current
                alpha = (total - f) / VG.FADE_FRAMES;
                // Fade in next slide underneath (draw next first, then current on top)
                _drawFrame(ctx, nextImg, captions[(slideIdx + 1) % N] || '', 0, 1 - alpha);
            }
            _drawFrame(ctx, img, cap, progress, alpha);

            globalFrame++;

            // Yield to browser (mandatory for MediaRecorder to collect frames)
            await new Promise(r => setTimeout(r, MS_PER_FRAME));

            // Progress update every 30 frames (every second of video)
            if (globalFrame % VG.FPS === 0 || globalFrame === VG.TOTAL_FRAMES) {
                const elapsed = Math.round(globalFrame / VG.FPS);
                const pct = 10 + Math.round((globalFrame / VG.TOTAL_FRAMES) * 86);
                onProgress(`Rendering… ${elapsed}s / ${VG.DURATION_S}s  (photo ${slideIdx + 1}/${N})`, pct);
            }
        }
    }

    // ── 6. Finalize ──
    onProgress('Finalising video…', 97);
    recorder.stop();

    return new Promise((resolve, reject) => {
        recorder.onstop = () => {
            if (chunks.length === 0) { reject(new Error('No video data recorded.')); return; }
            const blob = new Blob(chunks, { type: mimeType });
            onProgress('✅ Video ready!', 100);
            resolve(blob);
        };
        recorder.onerror = (e) => reject(e.error || new Error('MediaRecorder error'));
    });
}

// ─── Validate a file before adding ────────────────────────────────────────────
/**
 * Returns null if OK, or an error string if rejected.
 * @param {File} f
 */
function validateImageFile(f) {
    const ext = f.name.split('.').pop().toLowerCase();
    const isImage = f.type.startsWith('image/') || VG.RAW_EXTS.has(ext);
    if (!isImage) return `"${f.name}" is not a supported image format.`;
    if (f.size > VG.MAX_MB * 1024 * 1024) return `"${f.name}" exceeds ${VG.MAX_MB} MB limit.`;
    return null;
}

// Export for use in app.js
window.VG = VG;
window.generateReelVideo = generateReelVideo;
window.validateImageFile = validateImageFile;
