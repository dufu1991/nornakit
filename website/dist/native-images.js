export const setNativeImage = (container, { stem, alt, loading = 'lazy' }) => {
  container.classList.add('native-screenshot');
  for (const appearance of ['light', 'dark']) {
    let image = container.querySelector(`[data-image-theme="${appearance}"]`);
    if (!image) {
      image = document.createElement('img');
      image.dataset.imageTheme = appearance;
      image.decoding = 'async';
      container.append(image);
    }
    const source = `assets/${stem}-${appearance}.png`;
    if (image.getAttribute('src') !== source) image.src = source;
    image.alt = alt;
    image.loading = loading;
  }
};

export const createNativeImage = (options) => {
  const container = document.createElement('span');
  setNativeImage(container, options);
  return container;
};
