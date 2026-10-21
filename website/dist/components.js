const icons = {
  chevron: '<path d="m8 10 4 4 4-4"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a17 17 0 0 1 0 18 17 17 0 0 1 0-18Z"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  system: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>',
  light: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
  dark: '<path d="M20.5 13a8.5 8.5 0 0 1-9.5-9.5A8.5 8.5 0 1 0 20.5 13Z"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4.5 4.5"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  expand: '<path d="M14 4h6v6M20 4l-7 7M10 20H4v-6M4 20l7-7"/>',
  arrow: '<path d="M5 12h14m-5-5 5 5-5 5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>'
};
export const icon = (name) => `<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name]}</svg>`;
let openPicker;

export const createPicker = ({ host, id, searchable = false, compact = false, onChange }) => {
  const trigger = document.createElement('button');
  trigger.type = 'button'; trigger.id = id; trigger.className = `ui-select-trigger${compact ? ' ui-select-compact' : ''}`;
  trigger.setAttribute('role', 'combobox'); trigger.setAttribute('aria-haspopup', 'listbox');
  trigger.setAttribute('aria-controls', `${id}-list`); trigger.setAttribute('aria-expanded', 'false');
  host.append(trigger);
  const popup = document.createElement('div');
  popup.className = `ui-popover${searchable ? ' ui-popover-searchable' : ''}`; popup.hidden = true;
  const heading = document.createElement('div'); heading.className = 'ui-popover-heading';
  popup.append(heading);
  let search;
  if (searchable) {
    const wrapper = document.createElement('div'); wrapper.className = 'ui-search'; wrapper.innerHTML = icon('search');
    search = document.createElement('input'); search.type = 'search'; search.autocomplete = 'off'; search.spellcheck = false;
    search.setAttribute('aria-controls', `${id}-list`); wrapper.append(search); popup.append(wrapper);
  }
  const list = document.createElement('div'); list.id = `${id}-list`; list.role = 'listbox'; list.tabIndex = -1; list.className = 'ui-option-list'; popup.append(list);
  const empty = document.createElement('p'); empty.className = 'ui-empty'; empty.role = 'status'; empty.hidden = true; popup.append(empty);
  document.body.append(popup);
  let options = [], visible = [], value, active = 0, typeahead = '', typeTimer;
  const position = () => {
    if (popup.hidden) return;
    const rect = trigger.getBoundingClientRect();
    const viewport = window.visualViewport;
    const width = viewport ? viewport.width : window.innerWidth;
    const height = viewport ? viewport.height : window.innerHeight;
    const offsetTop = viewport ? viewport.offsetTop : 0;
    const offsetLeft = viewport ? viewport.offsetLeft : 0;
    const desiredWidth = searchable ? Math.max(rect.width, 300) : 228;
    popup.style.width = `${Math.min(desiredWidth, width - 24)}px`;
    const left = Math.max(offsetLeft + 12, Math.min(rect.right - popup.offsetWidth, offsetLeft + width - popup.offsetWidth - 12));
    popup.style.left = `${left}px`;
    popup.style.maxHeight = `${height - 24}px`;
    const spaceBelow = offsetTop + height - rect.bottom - 12;
    const spaceAbove = rect.top - offsetTop - 12;
    const below = spaceBelow >= Math.min(popup.scrollHeight, 280) || spaceBelow >= spaceAbove;
    const available = Math.max(100, below ? spaceBelow - 8 : spaceAbove - 8);
    list.style.maxHeight = `${Math.max(60, Math.min(searchable ? 286 : 220, available - (searchable ? 86 : 38)))}px`;
    popup.style.top = `${below ? rect.bottom + 8 : Math.max(offsetTop + 12, rect.top - popup.offsetHeight - 8)}px`;
  };
  const focusActive = (scroll = true) => {
    const buttons = [...list.children];
    buttons.forEach((button, index) => button.classList.toggle('is-active', index === active));
    const current = buttons[active];
    if (current) {
      list.setAttribute('aria-activedescendant', current.id);
      if (search) search.setAttribute('aria-activedescendant', current.id);
      if (scroll) current.scrollIntoView({ block: 'nearest' });
    } else {
      list.removeAttribute('aria-activedescendant');
      search?.removeAttribute('aria-activedescendant');
    }
  };
  const close = (restoreFocus = false) => {
    popup.hidden = true; trigger.setAttribute('aria-expanded', 'false');
    if (openPicker === api) openPicker = undefined;
    if (restoreFocus) trigger.focus();
  };
  const choose = (option) => { value = option.value; close(true); onChange(value); };
  const render = () => {
    const query = search ? search.value.trim().toLocaleLowerCase() : '';
    visible = options.filter((option) => `${option.label} ${option.searchText || ''}`.toLocaleLowerCase().includes(query));
    list.replaceChildren(...visible.map((option, index) => {
      const button = document.createElement('button'); button.type = 'button'; button.role = 'option'; button.tabIndex = -1;
      button.id = `${id}-option-${index}`; button.className = 'ui-option';
      button.setAttribute('aria-selected', String(option.value === value));
      if (option.icon) { const glyph = document.createElement('span'); glyph.className = 'ui-option-icon'; glyph.innerHTML = icon(option.icon); button.append(glyph); }
      const copy = document.createElement('span'); copy.className = 'ui-option-copy';
      const label = document.createElement('span'); label.textContent = option.label; copy.append(label);
      const check = document.createElement('span'); check.className = 'ui-option-check'; check.innerHTML = icon('check');
      button.append(copy, check);
      button.addEventListener('click', () => choose(option));
      button.addEventListener('pointermove', (event) => { if (event.pointerType === 'mouse') { active = index; focusActive(false); } });
      return button;
    }));
    empty.hidden = visible.length > 0; list.hidden = visible.length === 0;
    active = Math.max(0, visible.findIndex((option) => option.value === value)); focusActive(false); position();
  };
  const open = (last = false) => {
    openPicker?.close(); openPicker = api;
    if (search) search.value = '';
    popup.hidden = false; trigger.setAttribute('aria-expanded', 'true'); render();
    if (last) active = visible.length - 1;
    position(); (search || list).focus({ preventScroll: true }); focusActive();
  };
  const update = (next) => {
    options = next.options; value = next.value;
    trigger.setAttribute('aria-label', `${next.label}${next.iconOnly ? ` — ${next.display}` : ''}`);
    trigger.classList.toggle('ui-select-icon-only', !!next.iconOnly);
    trigger.innerHTML = `${icon(next.icon)}<span class="ui-select-value"></span>${next.iconOnly ? '' : icon('chevron')}`;
    trigger.querySelector('.ui-select-value').textContent = next.display;
    heading.textContent = next.label; list.setAttribute('aria-label', next.label);
    if (search) { search.placeholder = next.searchPlaceholder; search.setAttribute('aria-label', next.searchPlaceholder); }
    empty.textContent = next.emptyText;
    if (!popup.hidden) render();
  };
  trigger.addEventListener('click', () => popup.hidden ? open() : close());
  trigger.addEventListener('keydown', (event) => {
    if (['ArrowDown', 'ArrowUp'].includes(event.key)) { event.preventDefault(); open(event.key === 'ArrowUp'); }
  });
  popup.addEventListener('keydown', (event) => {
    if (event.isComposing) return;
    if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); close(true); return; }
    if (event.key === 'Tab') { close(true); return; }
    if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key) && !(search && ['Home','End'].includes(event.key) && event.target === search)) {
      event.preventDefault();
      if (!visible.length) return;
      active = event.key === 'Home' ? 0 : event.key === 'End' ? visible.length - 1 : (active + (event.key === 'ArrowDown' ? 1 : -1) + visible.length) % visible.length;
      focusActive();
    } else if (event.key === 'Enter' || !search && event.key === ' ') {
      event.preventDefault(); if (visible[active]) choose(visible[active]);
    } else if (!search && event.key.length === 1 && !event.metaKey && !event.ctrlKey && !event.altKey) {
      event.preventDefault(); typeahead += event.key.toLocaleLowerCase(); clearTimeout(typeTimer);
      typeTimer = setTimeout(() => { typeahead = ''; }, 600);
      const index = visible.findIndex((option) => option.label.toLocaleLowerCase().startsWith(typeahead));
      if (index >= 0) { active = index; focusActive(); }
    }
  });
  search?.addEventListener('input', render);
  document.addEventListener('pointerdown', (event) => { if (!popup.hidden && !host.contains(event.target) && !popup.contains(event.target)) close(); });
  document.addEventListener('focusin', (event) => { if (!popup.hidden && !host.contains(event.target) && !popup.contains(event.target)) close(); });
  window.addEventListener('resize', position);
  window.addEventListener('scroll', (event) => { if (!popup.hidden && !popup.contains(event.target)) position(); }, true);
  window.visualViewport?.addEventListener('resize', position);
  window.visualViewport?.addEventListener('scroll', position);
  const api = { update, close, setValue: (next) => { value = next; const option = options.find((item) => item.value === value); if (option) { trigger.querySelector('.ui-select-value').textContent = option.label; } if (!popup.hidden) render(); } };
  return api;
};
