const nornaSettings = (() => {
  const read = (key) => window.localStorage.getItem(`norna-${key}`);
  const languagePreference = read('language') || 'auto';
  const themePreference = read('theme') || 'auto';
  const resolveLanguage = (preference) => preference === 'auto' ? ((navigator.languages || [navigator.language])[0].toLowerCase().startsWith('zh') ? 'zh' : 'en') : preference;
  const resolveTheme = (preference) => preference === 'auto' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : preference;
  const apply = (language, theme) => {
    document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
    document.documentElement.dataset.theme = theme;
    document.querySelector('meta[name="theme-color"]').content = theme === 'dark' ? '#171719' : '#fafaf9';
  };
  apply(resolveLanguage(languagePreference), resolveTheme(themePreference));
  return { languagePreference, themePreference, resolveLanguage, resolveTheme, apply };
})();
