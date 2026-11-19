import React, { useState, useEffect } from 'react';
import {
  Save,
  Key,
  Database,
  Moon,
  Sun,
  Laptop,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Lock,
  Mail,
  FolderPlus,
} from 'lucide-react';
import { getSettings, saveSettings, applyTheme } from '@/storage/draftStore';
import { ExtensionSettings } from '@/services/types';
import { getSupabaseClient } from '@/services/supabase';

export default function App() {
  const [settings, setSettings] = useState<ExtensionSettings>({
    supabaseUrl: '',
    supabaseAnonKey: '',
    email: '',
    theme: 'system',
    inboxPageTitle: 'Входящие / Web Clips',
    showFloatingButton: true,
  });
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [testing, setTesting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [testResult, setTestResult] = useState<{ ok: boolean; message: string } | null>(null);

  useEffect(() => {
    getSettings().then(setSettings);
  }, []);

  async function handleSave(e?: React.FormEvent) {
    if (e) e.preventDefault();
    setLoading(true);
    setSuccess(false);

    try {
      await saveSettings(settings);
      applyTheme(settings.theme);
      setSuccess(true);
      setTimeout(() => setSuccess(false), 2000);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  async function handleTestAndLogin() {
    setTesting(true);
    setTestResult(null);

    try {
      await saveSettings(settings);
      const client = await getSupabaseClient();
      if (!client) {
        throw new Error('Укажите корректный URL и Anon Key.');
      }

      if (password && settings.email) {
        const { error } = await client.auth.signInWithPassword({
          email: settings.email.trim(),
          password,
        });
        if (error) {
          throw new Error(`Ошибка входа: ${error.message}`);
        }
      }

      const { data: sessionData } = await client.auth.getSession();
      if (!sessionData.session) {
        setTestResult({
          ok: true,
          message: 'Подключение к серверу успешно установлено, но требуется вход по Email и паролю.',
        });
      } else {
        setTestResult({
          ok: true,
          message: `Успешно авторизован как ${sessionData.session.user.email}`,
        });
      }
    } catch (err: unknown) {
      setTestResult({
        ok: false,
        message: err instanceof Error ? err.message : String(err),
      });
    } finally {
      setTesting(false);
    }
  }

  return (
    <div className="bg-df-surface-light dark:bg-df-surface-dark border border-df-divider-light dark:border-df-divider-dark rounded-popover shadow-popover overflow-hidden text-df-text-light dark:text-df-text-dark font-sans select-none">
      {/* Header */}
      <div className="px-6 py-5 border-b border-df-divider-light dark:border-df-divider-dark bg-df-surfaceSubtle-light dark:bg-df-card-dark flex items-center justify-between">
        <div className="flex items-center gap-3.5">
          <img src="/icon-48.png" alt="DraftFlow" className="w-9 h-9 rounded-card shadow-card shrink-0" />
          <div>
            <h1 className="text-sm font-bold text-df-text-light dark:text-df-text-dark">Настройки DraftFlow Companion</h1>
            <p className="text-xs text-df-muted-light dark:text-df-muted-dark">
              Синхронизация с базой данных Supabase и параметры расширения
            </p>
          </div>
        </div>
      </div>

      {/* Form */}
      <form onSubmit={handleSave} className="p-6 space-y-5">
        {/* Supabase Connection */}
        <div className="space-y-3">
          <h2 className="text-[11px] font-semibold uppercase tracking-wider text-df-faint-light dark:text-df-faint-dark">
            Подключение к Supabase
          </h2>

          <div className="space-y-1">
            <label className="text-xs font-medium flex items-center gap-1.5 text-df-muted-light dark:text-df-muted-dark">
              <Database className="w-3.5 h-3.5 text-accent" />
              Supabase Project URL
            </label>
            <input
              type="url"
              required
              value={settings.supabaseUrl}
              onChange={(e) => setSettings({ ...settings, supabaseUrl: e.target.value })}
              placeholder="https://your-project.supabase.co"
              className="w-full px-3 py-2 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark"
            />
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium flex items-center gap-1.5 text-df-muted-light dark:text-df-muted-dark">
              <Key className="w-3.5 h-3.5 text-accent" />
              Supabase Anon Key
            </label>
            <input
              type="password"
              required
              value={settings.supabaseAnonKey}
              onChange={(e) => setSettings({ ...settings, supabaseAnonKey: e.target.value })}
              placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
              className="w-full px-3 py-2 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark font-mono"
            />
          </div>
        </div>

        {/* Authentication */}
        <div className="space-y-3 pt-2 border-t border-df-divider-light dark:border-df-divider-dark">
          <h2 className="text-[11px] font-semibold uppercase tracking-wider text-df-faint-light dark:text-df-faint-dark">
            Авторизация в аккаунте
          </h2>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="text-xs font-medium flex items-center gap-1.5 text-df-muted-light dark:text-df-muted-dark">
                <Mail className="w-3.5 h-3.5 text-accent" />
                Email
              </label>
              <input
                type="email"
                value={settings.email}
                onChange={(e) => setSettings({ ...settings, email: e.target.value })}
                placeholder="user@example.com"
                className="w-full px-3 py-2 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark"
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium flex items-center gap-1.5 text-df-muted-light dark:text-df-muted-dark">
                <Lock className="w-3.5 h-3.5 text-accent" />
                Пароль (для входа)
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full px-3 py-2 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark font-mono"
              />
            </div>
          </div>

          <button
            type="button"
            onClick={handleTestAndLogin}
            disabled={testing || !settings.supabaseUrl}
            className="text-xs font-medium text-accent hover:text-accent-hover flex items-center gap-1.5 transition py-1"
          >
            {testing ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" />}
            Проверить соединение и войти
          </button>

          {testResult && (
            <div
              className={`p-3 rounded-control text-xs flex items-center gap-2 ${
                testResult.ok
                  ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20'
                  : 'bg-red-500/10 text-red-600 dark:text-red-400 border border-red-500/20'
              }`}
            >
              {testResult.ok ? <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-500" /> : <AlertCircle className="w-4 h-4 shrink-0" />}
              <span>{testResult.message}</span>
            </div>
          )}
        </div>

        {/* General Preferences */}
        <div className="space-y-3 pt-2 border-t border-df-divider-light dark:border-df-divider-dark">
          <h2 className="text-[11px] font-semibold uppercase tracking-wider text-df-faint-light dark:text-df-faint-dark">
            Опции клиппера
          </h2>

          <div className="space-y-1">
            <label className="text-xs font-medium flex items-center gap-1.5 text-df-muted-light dark:text-df-muted-dark">
              <FolderPlus className="w-3.5 h-3.5 text-accent" />
              Название раздела «Входящие» по умолчанию
            </label>
            <input
              type="text"
              value={settings.inboxPageTitle}
              onChange={(e) => setSettings({ ...settings, inboxPageTitle: e.target.value })}
              placeholder="Входящие / Web Clips"
              className="w-full px-3 py-2 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark"
            />
          </div>

          <div className="flex items-center justify-between pt-2">
            <div>
              <div className="text-xs font-medium text-df-text-light dark:text-df-text-dark">
                Плавающая кнопка при выделении текста
              </div>
              <div className="text-[11px] text-df-muted-light dark:text-df-muted-dark">
                Показывать кнопку сохранения «В DraftFlow» рядом с выделенным текстом
              </div>
            </div>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={settings.showFloatingButton ?? true}
                onChange={(e) => setSettings({ ...settings, showFloatingButton: e.target.checked })}
                className="sr-only peer"
              />
              <div className="w-9 h-5 bg-black/10 dark:bg-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-neutral-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-accent"></div>
            </label>
          </div>

          {/* Theme selector */}
          <div className="space-y-1 pt-2">
            <label className="text-xs font-medium text-df-muted-light dark:text-df-muted-dark">
              Тема оформления
            </label>
            <div className="grid grid-cols-3 gap-2">
              <button
                type="button"
                onClick={() => setSettings({ ...settings, theme: 'system' })}
                className={`py-2 px-3 rounded-control text-xs font-medium border flex items-center justify-center gap-1.5 transition ${
                  settings.theme === 'system'
                    ? 'border-accent bg-accent/10 text-accent font-semibold shadow-sm'
                    : 'border-df-divider-light dark:border-df-divider-dark hover:bg-black/5 dark:hover:bg-white/5 text-df-muted-light dark:text-df-muted-dark'
                }`}
              >
                <Laptop className="w-3.5 h-3.5" />
                Системная
              </button>
              <button
                type="button"
                onClick={() => setSettings({ ...settings, theme: 'light' })}
                className={`py-2 px-3 rounded-control text-xs font-medium border flex items-center justify-center gap-1.5 transition ${
                  settings.theme === 'light'
                    ? 'border-accent bg-accent/10 text-accent font-semibold shadow-sm'
                    : 'border-df-divider-light dark:border-df-divider-dark hover:bg-black/5 dark:hover:bg-white/5 text-df-muted-light dark:text-df-muted-dark'
                }`}
              >
                <Sun className="w-3.5 h-3.5" />
                Светлая
              </button>
              <button
                type="button"
                onClick={() => setSettings({ ...settings, theme: 'dark' })}
                className={`py-2 px-3 rounded-control text-xs font-medium border flex items-center justify-center gap-1.5 transition ${
                  settings.theme === 'dark'
                    ? 'border-accent bg-accent/10 text-accent font-semibold shadow-sm'
                    : 'border-df-divider-light dark:border-df-divider-dark hover:bg-black/5 dark:hover:bg-white/5 text-df-muted-light dark:text-df-muted-dark'
                }`}
              >
                <Moon className="w-3.5 h-3.5" />
                Темная
              </button>
            </div>
          </div>
        </div>

        {/* Save button */}
        <div className="pt-4 flex justify-end">
          <button
            type="submit"
            disabled={loading}
            className="py-2.5 px-6 bg-accent hover:bg-accent-hover active:scale-[0.98] text-white font-medium rounded-control transition-all flex items-center gap-2 text-xs shadow-card"
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : success ? <CheckCircle2 className="w-4 h-4" /> : <Save className="w-4 h-4" />}
            {success ? 'Сохранено!' : 'Сохранить настройки'}
          </button>
        </div>
      </form>
    </div>
  );
}
