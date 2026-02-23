/* ══════════════════════════════════════════════════════════════════════════════
   TravelBuddy AI — app.js
   • 100 % offline capable (video generated client-side via video_generator.js)
   • Backend (http://127.0.0.1:8000) used for AI analysis + story — optional
   • Max 50 photos · 50 MB each · all browser-decodable image formats + RAW
   • Drag-and-drop zone + click-to-browse  (both fully wired)
   • Drag-to-REORDER thumbnails in the preview grid
   ══════════════════════════════════════════════════════════════════════════════ */
'use strict';

const API = '';
const MAX_FILES = 50;
const MAX_MB = 50;

// All accepted image extensions (for tooltip / filtering)
const ACCEPTED_EXTS = new Set([
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'avif', 'svg', 'tiff', 'tif',
    'heic', 'heif',
    // RAW (displayed as placeholder card — browser limitation)
    'nef', 'cr2', 'arw', 'dng', 'raw', 'raf', 'orf', 'rw2', 'pef',
]);

// ── State ─────────────────────────────────────────────────────────────────────
const state = {
    photos: [],          // Array<File>
    analysed: [],          // backend ranked results
    storyData: null,
    slideTimer: null,
    interests: [],
    destination: '',
    tone: 'adventurous and inspiring',
    // drag-reorder
    _dragIdx: null,
};

// ── DOM helpers ───────────────────────────────────────────────────────────────
const $ = (id) => document.getElementById(id);
const qs = (sel) => document.querySelector(sel);

function setLoading(btnId, spinnerId, on, label) {
    const btn = $(btnId), sp = $(spinnerId);
    if (!btn || !sp) return;
    btn.disabled = on;
    btn.classList.toggle('loading', on);
    if (label) { const s = btn.querySelector('span:first-child'); if (s) s.textContent = label; }
    sp.style.display = on ? 'inline-block' : 'none';
}

function showErr(id, msg) {
    const el = $(id);
    if (!el) return;
    el.textContent = msg || '';
    el.classList.toggle('show', !!msg);
}

function showToast(msg, duration = 3000) {
    const t = $('toast');
    if (!t) return;
    t.textContent = msg;
    t.classList.remove('hidden');
    setTimeout(() => t.classList.add('hidden'), duration);
}

function fmt(n) { return n != null ? '₹' + Number(n).toLocaleString('en-IN') : '—'; }

// ── Tab navigation ────────────────────────────────────────────────────────────
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(b => {
            b.classList.remove('active');
            b.setAttribute('aria-selected', 'false');
        });
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.add('hidden'));
        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');
        const paneId = 'tab' + btn.dataset.tab.charAt(0).toUpperCase() + btn.dataset.tab.slice(1);
        $(paneId)?.classList.remove('hidden');
        window.scrollTo({ top: 0, behavior: 'smooth' });
    });
});

$('goReelTabBtn')?.addEventListener('click', () => $('tabReelBtn')?.click());

// ══════════════════════════════════════════════════════════════════════════════
// ██  TAB 1 — PHOTO → REEL
// ══════════════════════════════════════════════════════════════════════════════

const dropZone = $('dropZone');
const photoInput = $('photoInput');
const photoGrid = $('photoGrid');
const dropPh = $('dropPh');

// ── Click-to-browse ───────────────────────────────────────────────────────────
$('browseBtn')?.addEventListener('click', (e) => { e.stopPropagation(); photoInput.click(); });
dropZone?.addEventListener('click', (e) => {
    if (!e.target.closest('.thumb-del') && !e.target.closest('.thumb')) photoInput.click();
});
dropZone?.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') photoInput.click(); });
photoInput?.addEventListener('change', () => { addFiles([...photoInput.files]); photoInput.value = ''; });

// ── Drag-and-drop FROM OS (adding new photos) ─────────────────────────────────
dropZone?.addEventListener('dragover', (e) => { e.preventDefault(); dropZone.classList.add('drag-over'); });
dropZone?.addEventListener('dragleave', (e) => {
    // Only remove class if leaving the zone itself (not a child)
    if (!dropZone.contains(e.relatedTarget)) dropZone.classList.remove('drag-over');
});
dropZone?.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('drag-over');

    // Ignore internal thumbnail reorder drops
    if (state._dragIdx !== null) return;

    const files = [...e.dataTransfer.files].filter(f => {
        const ext = f.name.split('.').pop().toLowerCase();
        return f.type.startsWith('image/') || ACCEPTED_EXTS.has(ext);
    });
    addFiles(files);
});

// ── Add files (validate, dedup, limit) ───────────────────────────────────────
function addFiles(files) {
    showErr('uploadErr', '');
    let skipped = 0, skippedNames = [];

    for (const f of files) {
        if (state.photos.length >= MAX_FILES) {
            skipped++;
            continue;
        }
        const err = window.validateImageFile ? window.validateImageFile(f) : null;
        if (err) {
            skipped++;
            skippedNames.push(f.name);
            showErr('uploadErr', err);
            continue;
        }
        // Dedup by name + size
        const dup = state.photos.some(p => p.name === f.name && p.size === f.size);
        if (!dup) state.photos.push(f);
    }

    if (skipped > 1) {
        showErr('uploadErr', `${skipped} files skipped — exceeded ${MAX_FILES} photo limit or ${MAX_MB} MB size limit.`);
    }
    renderGrid();
}

// ── Render thumbnail grid + drag-to-reorder wiring ───────────────────────────
function renderGrid() {
    photoGrid.innerHTML = '';

    state.photos.forEach((f, i) => {
        const wrap = document.createElement('div');
        wrap.className = 'thumb';
        wrap.draggable = true;
        wrap.dataset.idx = i;

        const ext = f.name.split('.').pop().toLowerCase();
        const isRaw = window.VG ? window.VG.RAW_EXTS.has(ext) : ['nef', 'cr2', 'arw', 'dng', 'raw'].includes(ext);

        // Check if backend already analysed and refined this (we check state.analysed)
        const analysis = state.analysed.find(a => a.image_path && a.image_path.split(/[/\\]/).pop() === f.name);
        const refinedUrl = (analysis && analysis.refined_path) ? `${API}/${analysis.refined_path}` : '';
        const blobUrl = isRaw ? '' : URL.createObjectURL(f);

        wrap.innerHTML = `
            ${refinedUrl
                ? `<img src="${refinedUrl}" alt="${f.name}" loading="lazy">`
                : (isRaw
                    ? `<div class="thumb-raw-ph"><span>📷</span><small>${ext.toUpperCase()}</small></div>`
                    : `<img src="${blobUrl}" alt="${f.name}" loading="lazy">`
                )
            }
            <div class="thumb-order">${i + 1}</div>
            <button class="thumb-del" type="button" title="Remove" data-idx="${i}">✕</button>
            ${(isRaw && !refinedUrl) ? `<span class="raw-tag">RAW</span>` : ''}
        `;

        // Remove button
        wrap.querySelector('.thumb-del').addEventListener('click', (e) => {
            e.stopPropagation();
            removePhoto(parseInt(e.currentTarget.dataset.idx));
        });

        // ── Drag-to-reorder (HTML5 Drag API within the grid) ──
        wrap.addEventListener('dragstart', (e) => {
            state._dragIdx = i;
            wrap.classList.add('dragging');
            e.dataTransfer.effectAllowed = 'move';
            e.dataTransfer.setData('text/plain', String(i)); // required in Firefox
        });
        wrap.addEventListener('dragend', () => {
            state._dragIdx = null;
            wrap.classList.remove('dragging');
            document.querySelectorAll('.thumb').forEach(t => t.classList.remove('drag-target'));
        });
        wrap.addEventListener('dragover', (e) => {
            e.preventDefault();
            if (state._dragIdx !== null && state._dragIdx !== i) {
                e.dataTransfer.dropEffect = 'move';
                document.querySelectorAll('.thumb').forEach(t => t.classList.remove('drag-target'));
                wrap.classList.add('drag-target');
            }
        });
        wrap.addEventListener('drop', (e) => {
            e.preventDefault();
            e.stopPropagation();          // prevent the zone-level drop handler
            const from = state._dragIdx;
            if (from === null || from === i) return;
            // Reorder
            const moved = state.photos.splice(from, 1)[0];
            state.photos.splice(i, 0, moved);
            state._dragIdx = null;
            renderGrid();
        });

        photoGrid.appendChild(wrap);
    });

    const n = state.photos.length;
    const hasPhotos = n > 0;
    dropPh.style.display = hasPhotos ? 'none' : 'flex';
    photoGrid.style.display = hasPhotos ? 'grid' : 'none';
    $('countBar').style.display = hasPhotos ? 'flex' : 'none';
    $('countLabel').textContent = `${n} / ${MAX_FILES} photos selected`;
    $('analyseBtn').disabled = !hasPhotos;
}

function removePhoto(i) {
    state.photos.splice(i, 1);
    renderGrid();
}

$('clearBtn')?.addEventListener('click', () => { state.photos = []; renderGrid(); showErr('uploadErr', ''); });

// ── Analyse & Generate ────────────────────────────────────────────────────────
$('analyseBtn')?.addEventListener('click', async () => {
    showErr('uploadErr', '');
    state.destination = $('reelDest').value.trim();
    state.tone = $('reelTone').value;

    if (state.photos.length === 0) { showErr('uploadErr', 'Please add at least one photo.'); return; }

    setLoading('analyseBtn', 'analyseSpinner', true, '✨ Analysing photos…');

    try {
        // ── Try backend upload & AI analysis ──────────────────────────────────
        let uploadData = null;
        try {
            const fd = new FormData();
            state.photos.forEach(f => fd.append('files', f));
            const uploadResp = await fetch(`${API}/images/upload`, { method: 'POST', body: fd, signal: AbortSignal.timeout(120_000) });
            if (uploadResp.ok) uploadData = await uploadResp.json();
        } catch (backendErr) {
            console.warn('[App] Backend unavailable — running fully offline.', backendErr);
        }

        if (uploadData) {
            state.analysed = (uploadData.analysis_results?.ranked_results) || [];
            renderSelectedPhotos(uploadData);
        } else {
            // ── Offline: use all uploaded photos as-is ─────────────────────
            state.analysed = [];
            renderSelectedPhotosOffline();
        }

        // ── Try backend story generation ──────────────────────────────────────
        let storyData = null;
        try {
            const sceneTags = state.analysed.length > 0
                ? [...new Set(state.analysed.map(r => r.scene_tag || r.dominant_scene || 'travel'))]
                : (state.interests.length > 0 ? state.interests : ['travel', 'landscape', 'adventure']);

            const storyResp = await fetch(`${API}/story/generate`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ destination: state.destination || 'my trip', scene_tags: sceneTags, tone: state.tone }),
                signal: AbortSignal.timeout(90_000),
            });
            if (storyResp.ok) storyData = await storyResp.json();
        } catch (e) {
            console.warn('[App] Story API unavailable — using offline fallback.', e);
        }

        // ── Offline story fallback ────────────────────────────────────────────
        if (!storyData) storyData = buildOfflineStory(state.destination || 'My Trip', state.tone);

        state.storyData = storyData;
        renderStory(storyData);

        $('reelStep2').classList.remove('hidden');
        $('reelStep3').classList.remove('hidden');
        $('reelStep2').scrollIntoView({ behavior: 'smooth' });

    } catch (err) {
        showErr('uploadErr', `Error: ${err.message}`);
        console.error(err);
    } finally {
        setLoading('analyseBtn', 'analyseSpinner', false, '✨ Analyse & Generate Reel Story');
    }
});

// ── Offline story builder ─────────────────────────────────────────────────────
function buildOfflineStory(dest, tone) {
    const tonesMap = {
        'adventurous and inspiring': { adj: 'epic', verb: 'chased' },
        'dreamy and peaceful': { adj: 'dreamy', verb: 'wandered through' },
        'funny and light-hearted': { adj: 'hilarious', verb: 'survived' },
        'emotional and nostalgic': { adj: 'unforgettable', verb: 'cherished' },
    };
    const t = tonesMap[tone] || tonesMap['adventurous and inspiring'];
    return {
        title: `${t.adj.charAt(0).toUpperCase() + t.adj.slice(1)} Memories — ${dest}`,
        narration: `We ${t.verb} every corner of ${dest}.\n\nEach photo holds a story — a moment frozen in time.\n\nSome places don't just fill your camera roll, they fill your soul.\n\n${dest} — once visited, never forgotten.`,
        captions: [
            `Hello, ${dest} 🌍`,
            'Where every corner is a postcard ✨',
            'Chasing the golden hour 🌅',
            'Flavours you\'ll dream about 🍜',
            'Hidden streets, endless stories 🗺️',
            'This view though 😍',
            'Wanderlust fully activated 🎒',
            'Memories in the making 🎬',
        ],
        hashtags: [`#${dest.replace(/\s+/g, '')}`, `#Visit${dest.replace(/\s+/g, '')}`, '#TravelReel', '#CinematicTravel', '#WanderlustVibes', '#TravelBuddy', '#ExploreMore', '#ReelItFeelIt'],
    };
}

// ── Render: offline (no backend) ──────────────────────────────────────────────
function renderSelectedPhotosOffline() {
    const grid = $('selectedGrid');
    grid.innerHTML = '';

    if (state.photos.length === 0) return;

    state.photos.forEach((f, i) => {
        const ext = f.name.split('.').pop().toLowerCase();
        const isRaw = window.VG ? window.VG.RAW_EXTS.has(ext) : false;
        const wrap = document.createElement('div');
        wrap.className = 'sel-wrap';

        if (isRaw) {
            wrap.innerHTML = `<div class="thumb-raw-ph" style="height:120px"><span>📷</span><small>${ext.toUpperCase()}</small></div><span class="sel-score">RAW</span>`;
        } else {
            const url = URL.createObjectURL(f);
            wrap.innerHTML = `<img src="${url}" alt="" loading="lazy"><span class="sel-score">#${i + 1}</span>`;
        }
        grid.appendChild(wrap);
    });

    $('selectedSummary').textContent = `${state.photos.length} photos loaded — running offline (no AI scoring)`;
    $('scoreInfo').innerHTML = `<strong>ℹ️ Offline mode:</strong> Backend not available. Photos used as uploaded. Start the backend for AI quality scoring.`;

    // Build slideshow from local blobs
    const urls = state.photos
        .filter(f => !((window.VG || {}).RAW_EXTS || new Set()).has(f.name.split('.').pop().toLowerCase()))
        .map(f => URL.createObjectURL(f));
    buildReelSlideshow(urls);
}

// ── Render: backend analysis ──────────────────────────────────────────────────
function renderSelectedPhotos(data) {
    const results = (data.analysis_results?.ranked_results) || [];
    const grid = $('selectedGrid');
    grid.innerHTML = '';

    results.forEach(r => {
        const filename = r.image_path ? r.image_path.split(/[/\\]/).pop() : '';
        const file = state.photos.find(f => f.name === filename);
        if (!file && !r.refined_path) return;

        const wrap = document.createElement('div');
        wrap.className = 'sel-wrap';
        const score = r.final_quality_score != null ? `${Math.round(r.final_quality_score)}%` : '';
        const visionLabel = r.quality_label || '';
        const imgUrl = r.refined_path ? `${API}/${r.refined_path}` : (file ? URL.createObjectURL(file) : '');

        wrap.innerHTML = `
            <img src="${imgUrl}" alt="" loading="lazy">
            ${score ? `<span class="sel-score">${score}</span>` : ''}
            ${visionLabel ? `<div class="vision-badge">${visionLabel}</div>` : ''}
        `;
        grid.appendChild(wrap);
    });

    $('selectedSummary').textContent = `${data.uploaded_count} unique shots ranked by AI quality scoring`;
    $('scoreInfo').innerHTML = `<strong>AI quality metrics used:</strong> Blur detection · Sharpness · Exposure · Contrast · Entropy · Face detection · Perceptual deduplication`;

    const slideshowUrls = results
        .map(r => {
            if (r.refined_path) return `${API}/${r.refined_path}`;
            const fn = r.image_path ? r.image_path.split(/[/\\]/).pop() : '';
            const f = state.photos.find(f => f.name === fn);
            return f ? URL.createObjectURL(f) : null;
        })
        .filter(Boolean);

    buildReelSlideshow(slideshowUrls);
}

// ── Reel slideshow preview ────────────────────────────────────────────────────
function buildReelSlideshow(urls) {
    const container = $('reelSlides');
    container.innerHTML = '';
    if (!urls.length) return;

    urls.forEach((url, i) => {
        const img = document.createElement('img');
        img.className = 'reel-slide' + (i === 0 ? ' active' : '');
        img.src = url;
        container.appendChild(img);
    });

    let cur = 0;
    if (state.slideTimer) clearInterval(state.slideTimer);
    state.slideTimer = setInterval(() => {
        const slides = container.querySelectorAll('.reel-slide');
        if (!slides.length) return;
        slides[cur].classList.remove('active');
        cur = (cur + 1) % slides.length;
        slides[cur].classList.add('active');
        const caps = state.storyData?.captions || [];
        if (caps.length) $('reelCapPrev').textContent = caps[cur % caps.length];
    }, 2200);
}

// ── Render story panel ────────────────────────────────────────────────────────
function renderStory(data) {
    $('storyTitle').textContent = data.title || '';
    $('narrationEdit').value = data.narration || '';
    $('captionsWrap').innerHTML = (data.captions || []).map(c =>
        `<div class="cap-item" onclick="copyCap('${c.replace(/'/g, "\\'")}')"><span>${c}</span><span class="cap-copy">tap to copy</span></div>`
    ).join('');
    $('hashtagsWrap').innerHTML = (data.hashtags || []).map(h => `<span class="tag">${h}</span>`).join('');
    if (data.captions?.length) $('reelCapPrev').textContent = data.captions[0];
}

// eslint-disable-next-line no-unused-vars
function copyCap(text) { navigator.clipboard.writeText(text).catch(() => { }); }
window.copyCap = copyCap;

// ── Copy buttons ──────────────────────────────────────────────────────────────
$('copyNarBtn')?.addEventListener('click', () => {
    navigator.clipboard.writeText($('narrationEdit').value).then(() => {
        $('copyNarBtn').textContent = '✅ Copied!';
        setTimeout(() => { $('copyNarBtn').textContent = '📋 Copy'; }, 2000);
    });
});
$('copyTagsBtn')?.addEventListener('click', () => {
    const tags = (state.storyData?.hashtags || []).join(' ');
    navigator.clipboard.writeText(tags).then(() => {
        $('copyTagsBtn').textContent = '✅ Copied!';
        setTimeout(() => { $('copyTagsBtn').textContent = '📋 Copy Hashtags'; }, 2000);
    });
});

// ── Share ─────────────────────────────────────────────────────────────────────
$('shareBtn')?.addEventListener('click', () => {
    const text = [state.storyData?.title || '', '', $('narrationEdit').value, '', (state.storyData?.hashtags || []).join(' ')].join('\n');
    if (navigator.share) { navigator.share({ title: 'TravelBuddy Reel', text }); }
    else { navigator.clipboard.writeText(text).then(() => alert('Story copied to clipboard!')); }
});

// ── Video generation (100 % offline — client-side Canvas+MediaRecorder) ───────
$('downloadReelBtn')?.addEventListener('click', async () => {
    // Collect image sources: prefer backend refined paths, fallback to original File objects
    let sources = [];
    const captions = state.storyData?.captions || [];

    if (state.analysed.length > 0) {
        // Backend was used — build source list from analysis results
        state.analysed.forEach(r => {
            if (r.refined_path) {
                sources.push(`${API}/${r.refined_path}`);
            } else {
                const fn = r.image_path ? r.image_path.split(/[/\\]/).pop() : '';
                const file = state.photos.find(f => f.name === fn);
                if (file) sources.push(file);
            }
        });
    }

    // Fallback: use all selected photos (File objects work offline, no network needed)
    if (sources.length === 0) {
        sources = [...state.photos];
    }

    if (sources.length === 0) {
        showErr('storyErr', 'No images found. Please add photos first.');
        return;
    }

    // Clamp to 50
    sources = sources.slice(0, 50);

    // UI: show progress
    const btn = $('downloadReelBtn');
    const sp = $('videoSpinner');
    btn.disabled = true;
    const lblSpan = btn.querySelector('span:first-child');
    if (lblSpan) lblSpan.textContent = '⏳ Rendering…';
    if (sp) sp.style.display = 'inline-block';
    $('videoProgressWrap').style.display = 'block';
    $('videoPlayerWrap').style.display = 'none';
    $('videoProgressBar').style.width = '0%';
    $('videoProgressLabel').textContent = 'Starting…';
    showErr('storyErr', '');

    try {
        if (typeof generateReelVideo !== 'function') throw new Error('Video generator not loaded. Ensure video_generator.js is included.');

        const blob = await generateReelVideo(sources, captions, (label, pct) => {
            $('videoProgressLabel').textContent = label;
            $('videoProgressBar').style.width = `${pct}%`;
        });

        // Show inline player
        const url = URL.createObjectURL(blob);
        const vid = $('generatedVideo');
        vid.src = url;
        $('videoPlayerWrap').style.display = 'block';
        vid.play().catch(() => { });

        // Auto-download
        const ext = blob.type.includes('mp4') ? 'mp4' : 'webm';
        const dest = (state.destination || 'reel').replace(/\s+/g, '_');
        const a = document.createElement('a');
        a.href = url;
        a.download = `TravelBuddy_${dest}_1min.${ext}`;
        a.click();

        $('videoProgressLabel').textContent = `✅ 1-minute reel ready! (${sources.length} photos · ${blob.type.includes('mp4') ? 'MP4' : 'WebM'})`;
        $('videoProgressBar').style.width = '100%';

    } catch (err) {
        showErr('storyErr', `Video error: ${err.message}`);
        console.error(err);
    } finally {
        btn.disabled = false;
        if (lblSpan) lblSpan.textContent = '🎬 Generate Video';
        if (sp) sp.style.display = 'none';
    }
});

// ── New Reel ──────────────────────────────────────────────────────────────────
$('newReelBtn')?.addEventListener('click', () => {
    state.photos = []; state.analysed = []; state.storyData = null;
    if (state.slideTimer) { clearInterval(state.slideTimer); state.slideTimer = null; }
    showErr('uploadErr', ''); showErr('storyErr', '');
    renderGrid();
    $('reelStep2').classList.add('hidden');
    $('reelStep3').classList.add('hidden');
    $('reelSlides').innerHTML = '';
    $('reelCapPrev').textContent = 'Your photos + narration = reel';
    $('videoProgressWrap').style.display = 'none';
    $('videoPlayerWrap').style.display = 'none';
    window.scrollTo({ top: 0, behavior: 'smooth' });
});

// ══════════════════════════════════════════════════════════════════════════════
// ██  TAB 2 — TRIP PLANNER
// ══════════════════════════════════════════════════════════════════════════════

// Interest chips
document.querySelectorAll('.i-chip').forEach(chip => {
    chip.addEventListener('click', () => {
        chip.classList.toggle('on');
        const v = chip.dataset.v;
        state.interests = chip.classList.contains('on')
            ? [...state.interests, v]
            : state.interests.filter(i => i !== v);
    });
});

// Form submit
$('itineraryForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    showErr('planErr', '');

    const dest = $('destination').value.trim();
    const days = parseInt($('days').value);
    const budget = $('budget').value;

    let valid = true;
    if (!dest) { $('destErr').textContent = 'Enter a city name.'; $('destErr').classList.add('show'); valid = false; }
    else { $('destErr').classList.remove('show'); }
    if (!days || days < 1 || days > 14) { $('daysErr').textContent = '1–14 days only.'; $('daysErr').classList.add('show'); valid = false; }
    else { $('daysErr').classList.remove('show'); }
    if (!valid) return;

    setLoading('planBtn', 'planSpinner', true, 'Generating City Guide (Local AI is slow)...');

    try {
        const resp = await fetch(`${API}/itinerary/generate`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ destination: dest, days, budget, interests: state.interests }),
            signal: AbortSignal.timeout(300_000),
        });
        if (!resp.ok) {
            const err = await resp.json().catch(() => ({}));
            throw new Error(err.detail || `Server error ${resp.status}`);
        }
        const data = await resp.json();
        renderPlan(data);
        $('planResult').classList.remove('hidden');
        $('planResult').scrollIntoView({ behavior: 'smooth' });
    } catch (err) {
        showErr('planErr', `Failed: ${err.message}`);
    } finally {
        setLoading('planBtn', 'planSpinner', false, 'Generate City Guide');
    }
});

// Render plan
function renderPlan(data) {
    $('tripMeta').innerHTML = `
        <div class="meta-dest">${data.destination}</div>
        <div class="meta-chips">
            <span class="meta-chip">📅 ${data.total_days} Days</span>
            <span class="meta-chip">💰 ${data.budget_category}</span>
            ${(data.interests || []).map(i => `<span class="meta-chip">• ${i}</span>`).join('')}
        </div>`;

    let raw = data.itinerary_ai_output;
    if (typeof raw === 'string') {
        try { const m = raw.match(/\{[\s\S]*\}/); raw = m ? JSON.parse(m[0]) : null; }
        catch (_) { raw = null; }
    }

    const dc = $('dayCards');
    dc.innerHTML = '';

    // 1. Normalize data into a standard flat list of {label, activities[]}
    let normalized = [];
    if (raw && Array.isArray(raw.days)) {
        // Modern RAG Format: { "days": [ { "day": 1, "morning": "..."}, ... ] }
        normalized = raw.days.map(d => ({
            label: `Day ${d.day || d.Day || '?'}`,
            activities: [
                d.morning ? `🌅 Morning: ${d.morning}` : null,
                d.afternoon ? `☀️ Afternoon: ${d.afternoon}` : null,
                d.evening ? `🌆 Evening: ${d.evening}` : null,
                d.notes ? `💡 Note: ${d.notes}` : null
            ].filter(Boolean)
        }));
    } else if (raw && typeof raw === 'object') {
        // Legacy Format: { "Day 1": ["act1", "act2"], "Day 2": "act3" }
        normalized = Object.entries(raw)
            .filter(([k]) => !['city', 'destination', 'meta', 'days'].includes(k.toLowerCase()))
            .map(([k, v]) => ({
                label: k,
                activities: Array.isArray(v) ? v : [String(v)]
            }));
    }

    // 2. Render the normalized list
    if (normalized.length > 0) {
        normalized.forEach((day, idx) => {
            const card = document.createElement('div');
            card.className = 'day-card';
            const items = day.activities.map(a => {
                const str = String(a); // Safety first
                const lc = str.toLowerCase();
                let cls = '';
                if (lc.includes('morning') || str.includes('🌅') || str.includes('🏛')) cls = 'morning';
                else if (lc.includes('afternoon') || str.includes('☀️')) cls = 'afternoon';
                else if (lc.includes('evening') || lc.includes('night') || str.includes('🌆')) cls = 'evening';
                else if (lc.includes('tip') || lc.includes('budget') || lc.includes('note') || str.includes('💡')) cls = 'tip';
                else if (lc.includes('hidden') || lc.includes('gem') || str.includes('🔍')) cls = 'gem';
                return `<li class="act-item ${cls}">${str}</li>`;
            }).join('');

            card.innerHTML = `
                <div class="day-hd" onclick="toggleDay(this)">
                    <div class="day-num">${idx + 1}</div>
                    <div class="day-name">${day.label}</div>
                    <span class="day-chevron ${idx === 0 ? 'open' : ''}">▾</span>
                </div>
                <div class="day-body" style="${idx !== 0 ? 'display:none' : ''}"><ul class="act-list">${items}</ul></div>`;
            dc.appendChild(card);
        });
    } else {
        dc.innerHTML = `<div class="card"><pre style="white-space:pre-wrap;font-size:14px">${String(data.itinerary_ai_output)}</pre></div>`;
    }
    renderBudget(data.hotel_and_budget_estimation);
}

// eslint-disable-next-line no-unused-vars
function toggleDay(hd) {
    const body = hd.nextElementSibling;
    const icon = hd.querySelector('.day-chevron');
    const open = body.style.display !== 'none';
    body.style.display = open ? 'none' : 'block';
    icon.classList.toggle('open', !open);
}
window.toggleDay = toggleDay;

function renderBudget(b) {
    const card = $('budgetCard');
    if (!b) { card?.classList.add('hidden'); return; }
    const rows = [
        ['🏨 Accommodation', b.accommodation],
        ['🍽 Food & Dining', b.food],
        ['🚆 Transport', b.transportation],
        ['🎟 Activities', b.activities],
        ['🛍 Shopping', b.shopping],
        ['🔧 Miscellaneous', b.miscellaneous],
    ].filter(([, v]) => v != null);
    if (!card) return;
    card.innerHTML = `
        <div class="budget-title">💸 Estimated Budget Breakdown</div>
        <table class="b-table">
            <tbody>${rows.map(([l, v]) => `<tr><td>${l}</td><td class="amt">${fmt(v)}</td></tr>`).join('')}</tbody>
            <tfoot><tr><td>Total Estimate</td><td class="amt">${fmt(b.estimated_total)}</td></tr></tfoot>
        </table>
        ${b.notes ? `<p class="b-note">${b.notes}</p>` : ''}`;
    card.classList.remove('hidden');
}

// ── LLM Status pill ───────────────────────────────────────────────────────────
async function checkLlmStatus() {
    const pill = $('llmPill');
    try {
        const resp = await fetch(`${API}/llm/status`, { signal: AbortSignal.timeout(5000) });
        if (!resp.ok) throw new Error();
        const s = await resp.json();
        const icons = { groq: '🟢', ollama: '🔵', mock: '🟡' };
        pill.innerHTML = `<span>${icons[s.provider] || '⚪'} ${s.label}</span> <small style="opacity:0.6;font-size:10px;margin-left:8px;border-left:1px solid rgba(0,0,0,0.1);padding-left:8px">Click to Switch</small>`;
        pill.className = `llm-pill ${s.provider}`;
        pill.title = s.detail;
    } catch {
        if (pill) { pill.textContent = '🔵 Offline Mode'; pill.className = 'llm-pill mock'; pill.title = 'Backend not running — video generation still works fully offline!'; }
    }
}

async function toggleLlmMode() {
    const pill = $('llmPill');
    if (pill.dataset.loading === 'true') return;

    console.log('[LLM] Requesting mode toggle...');
    pill.dataset.loading = 'true';
    const originalContent = pill.innerHTML;
    pill.innerHTML = `<span>⏳ Switching…</span>`;

    try {
        const resp = await fetch(`${API}/llm/toggle_mode`, { method: 'POST' });
        if (resp.ok) {
            const data = await resp.json();
            const modeName = data.prefer_local ? 'Local AI (Private/Slow)' : 'Cloud API (Fast/Smart)';
            console.log('[LLM] Mode toggled to:', modeName);
            showToast(`🚀 Switched to ${modeName}`);
            await checkLlmStatus();
        } else {
            console.error('[LLM] Toggle failed:', resp.status);
            showToast(`❌ Failed to switch mode: ${resp.status}`);
            pill.innerHTML = originalContent;
        }
    } catch (err) {
        console.error('[LLM] Failed to toggle mode:', err);
        showToast(`❌ Connection error during switch.`);
        pill.innerHTML = originalContent;
    } finally {
        pill.dataset.loading = 'false';
    }
}

// ── Init ──────────────────────────────────────────────────────────────────────
function initApp() {
    renderGrid();
    checkLlmStatus();

    // Auto-refresh status every 10 seconds to catch .env changes
    setInterval(checkLlmStatus, 10000);

    const pill = $('llmPill');
    if (pill) {
        pill.addEventListener('click', toggleLlmMode);
        pill.style.cursor = 'pointer';
        pill.title = 'Click to switch between Local (Private) and Cloud (Fast) AI';
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initApp);
} else {
    initApp();
}
