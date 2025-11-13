// cartoon_worker.js
// Runs in a Web Worker. Receives a File (image) via postMessage and returns a Blob (PNG) with a simple cartoon effect.

self.addEventListener('message', async (ev) => {
  const { id, file, maxDim = 800 } = ev.data || {};
  if (!file) return;
  try {
    postMessage({ id, type: 'progress', pct: 5, text: 'Loading image' });
    const imgBitmap = await createImageBitmap(file);

    // scale
    const w = imgBitmap.width;
    const h = imgBitmap.height;
    let scale = 1;
    if (Math.max(w, h) > maxDim) scale = maxDim / Math.max(w, h);
    const cw = Math.round(w * scale);
    const ch = Math.round(h * scale);

    const oc = new OffscreenCanvas(cw, ch);
    const ctx = oc.getContext('2d');
    ctx.drawImage(imgBitmap, 0, 0, cw, ch);
    postMessage({ id, type: 'progress', pct: 20, text: 'Resizing done' });

    // get image data
    let imgData = ctx.getImageData(0, 0, cw, ch);

    // 1) simple smoothing (box blur repeated) as a cheap bilateral substitute
    postMessage({ id, type: 'progress', pct: 35, text: 'Smoothing colors' });
    const smooth = (data, w, h, radius = 1, passes = 2) => {
      const out = new Uint8ClampedArray(data.length);
      for (let p = 0; p < passes; p++) {
        for (let y = 0; y < h; y++) {
          for (let x = 0; x < w; x++) {
            let r = 0, g = 0, b = 0, a = 0, n = 0;
            for (let yy = Math.max(0, y - radius); yy <= Math.min(h - 1, y + radius); yy++) {
              for (let xx = Math.max(0, x - radius); xx <= Math.min(w - 1, x + radius); xx++) {
                const i = (yy * w + xx) * 4;
                r += data[i]; g += data[i+1]; b += data[i+2]; a += data[i+3]; n++;
              }
            }
            const oi = (y * w + x) * 4;
            out[oi] = r / n; out[oi+1] = g / n; out[oi+2] = b / n; out[oi+3] = a / n;
          }
        }
        data = out.slice();
      }
      return data;
    };

    imgData.data.set(smooth(imgData.data, cw, ch, 1, 2));

    // 2) posterize (reduce color levels)
    postMessage({ id, type: 'progress', pct: 55, text: 'Posterizing' });
    const posterizeLevels = 6;
    for (let i = 0; i < imgData.data.length; i += 4) {
      imgData.data[i] = Math.floor(imgData.data[i] / 255 * (posterizeLevels - 1)) * (255 / (posterizeLevels - 1));
      imgData.data[i+1] = Math.floor(imgData.data[i+1] / 255 * (posterizeLevels - 1)) * (255 / (posterizeLevels - 1));
      imgData.data[i+2] = Math.floor(imgData.data[i+2] / 255 * (posterizeLevels - 1)) * (255 / (posterizeLevels - 1));
    }

    // write back color base
    ctx.putImageData(imgData, 0, 0);

    // 3) edge detection (Sobel) on grayscale
    postMessage({ id, type: 'progress', pct: 70, text: 'Detecting edges' });
    const gray = new Uint8ClampedArray(cw * ch);
    const src = imgData.data;
    for (let y = 0; y < ch; y++) {
      for (let x = 0; x < cw; x++) {
        const i = (y * cw + x) * 4;
        gray[y * cw + x] = 0.299 * src[i] + 0.587 * src[i+1] + 0.114 * src[i+2];
      }
    }

    const sobel = (g, w, h) => {
      const out = new Uint8ClampedArray(w * h);
      for (let y = 1; y < h - 1; y++) {
        for (let x = 1; x < w - 1; x++) {
          const idx = y * w + x;
          const gx = -g[idx - w - 1] - 2 * g[idx - 1] - g[idx + w - 1] + g[idx - w + 1] + 2 * g[idx + 1] + g[idx + w + 1];
          const gy = -g[idx - w - 1] - 2 * g[idx - w] - g[idx - w + 1] + g[idx + w - 1] + 2 * g[idx + w] + g[idx + w + 1];
          const mag = Math.min(255, Math.sqrt(gx * gx + gy * gy));
          out[idx] = mag;
        }
      }
      return out;
    };

    const edges = sobel(gray, cw, ch);

    // 4) composite: darken edges over posterized color
    postMessage({ id, type: 'progress', pct: 85, text: 'Compositing' });
    const edgeThreshold = 80;
    const outImg = ctx.getImageData(0, 0, cw, ch);
    for (let y = 0; y < ch; y++) {
      for (let x = 0; x < cw; x++) {
        const p = y * cw + x;
        const e = edges[p];
        const oi = p * 4;
        if (e > edgeThreshold) {
          // darken
          outImg.data[oi] = outImg.data[oi] * 0.1;
          outImg.data[oi+1] = outImg.data[oi+1] * 0.1;
          outImg.data[oi+2] = outImg.data[oi+2] * 0.1;
        }
      }
    }
    ctx.putImageData(outImg, 0, 0);

    postMessage({ id, type: 'progress', pct: 95, text: 'Finalizing' });
    const blob = await oc.convertToBlob({ type: 'image/png', quality: 0.92 });

    postMessage({ id, type: 'result', blob }, [blob]);
  } catch (err) {
    postMessage({ id, type: 'error', message: err?.message || String(err) });
  }
});
