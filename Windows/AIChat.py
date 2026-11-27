import sys, os, json, threading, time, base64, urllib.request, urllib.error
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext

BASE_DIR = os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__))
SETTINGS_PATH = os.path.join(BASE_DIR, 'settings.json')
CHATS_PATH = os.path.join(BASE_DIR, 'chats.json')
SUBJECTS = ['Авто', 'Универсально', 'Математика', 'Русский язык', 'Литература', 'Английский язык', 'История', 'География', 'Биология', 'Физика', 'Химия', 'Информатика', 'Обществознание']
FORMATS = ['Краткие ответы', 'Ответы с решением', 'Подробные ответы']

def load(path, default):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return default

def save(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def detect_subject(text):
    t = text.lower()
    rules = [('Математика', ['вычисли', 'уравнен', 'дроб', 'процент', 'периметр', 'площадь']), ('Русский язык', ['орфограмм', 'запят', 'подлежащ', 'сказуем', 'безударн']), ('Английский язык', ['translate', 'present simple', 'past simple']), ('История', ['в каком году', 'царь', 'война', 'реформ']), ('География', ['континент', 'столица', 'река', 'океан', 'климат']), ('Биология', ['клетк', 'фотосинтез', 'организм']), ('Физика', ['скорость', 'сила', 'масса', 'давление']), ('Химия', ['h2o', 'молекул', 'кислот', 'оксид']), ('Информатика', ['алгоритм', 'переменная', 'python', 'цикл'])]
    for name, keys in rules:
        for k in keys:
            if k in t:
                return name
    return 'Универсально'

def make_prompt(s, last):
    parts = [s.get('systemPrompt', 'Ты — полезный ИИ-ассистент. Отвечай на русском, кратко и по делу.')]
    if s.get('schoolMode', True):
        subject = s.get('schoolSubject', 'Универсально')
        if subject == 'Авто':
            subject = detect_subject(last)
        p = 'Ты — школьный помощник для 6 класса. Отвечай на русском, просто и кратко. Сначала прямой ответ, потом короткое объяснение. На фото может быть несколько заданий: решай все по порядку и нумеруй. ФОТО — ПРАВИЛО 90%: если не уверен минимум на 90%, что это именно это задание и ты прочитал номер, условие, числа и варианты точно, напиши ровно: Непонятно именно это задание — и укажи, что нечитаемо. Не додумывай. Математика: многозначное умножение и деление только в столбик по разрядам, дроби и проценты по шагам. Русский: подчёркивай сам тегами [[u:подлежащее]] [[ud:сказуемое]] [[dot:дополнение]] [[wave:определение]] [[dash:обстоятельство]], обводи [[circ:...]], выделяй [[hl:...]], итог [[box:Ответ: ...]]. Схемы рисуй блоком scheme, чертежи блоком draw, свободный холст блоком free с вопросом над словом и стрелкой.'
        p += chr(10) + 'Предмет: ' + subject + '. Формат: ' + s.get('schoolFormat', 'Кратко и по делу') + '.'
        if s.get('textbooks'):
            p += chr(10) + 'Мои учебники и тетради: ' + s['textbooks']
        if s.get('myStyle'):
            p += chr(10) + 'Мой стиль письма: ' + s['myStyle']
        parts.append(p)
    return (chr(10) + chr(10)).join(parts)

def api_url(s):
    return s.get('baseURL', 'https://positionapi.top/v1').rstrip('/')

def fetch_models(s):
    req = urllib.request.Request(api_url(s) + '/models', headers={'Authorization': 'Bearer ' + s.get('apiKey', '')})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read().decode('utf-8'))
    return sorted([m.get('id', '') for m in data.get('data', []) if m.get('id')])

def complete(s, messages):
    url = api_url(s) + '/chat/completions'
    body = {'model': s.get('selectedModel', ''), 'messages': messages, 'stream': False, 'temperature': 0.2 if s.get('schoolMode', True) else 0.7}
    delay = 1
    for attempt in range(15):
        try:
            req = urllib.request.Request(url, data=json.dumps(body).encode('utf-8'), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + s.get('apiKey', '')}, method='POST')
            with urllib.request.urlopen(req, timeout=90) as r:
                data = json.loads(r.read().decode('utf-8'))
            return data['choices'][0]['message']['content']
        except urllib.error.HTTPError as e:
            if e.code == 401:
                return 'Ошибка: неверный API-ключ (401).'
            if e.code == 402:
                return 'Ошибка: недостаточно средств (402).'
            if e.code == 404:
                return 'Ошибка: модель или адрес не найдены (404).'
            if e.code == 429 or e.code >= 500:
                if attempt == 14:
                    return 'Ошибка сервера после 15 попыток.'
                time.sleep(delay)
                delay = min(delay * 2, 8)
                continue
            return 'Ошибка HTTP ' + str(e.code)
        except Exception:
            if attempt == 14:
                return 'Ошибка сети после 15 попыток.'
            time.sleep(delay)
            delay = min(delay * 2, 8)
    return 'Ошибка после 15 попыток.'

def column_multiply(a, b):
    digits = [int(x) for x in str(b)[::-1]]
    lines = ['   ' + str(a), 'x  ' + str(b), '------']
    for i, d in enumerate(digits):
        lines.append(' ' * i + str(a * d) + '   ' + str(a) + ' x ' + str(d))
    lines.append('--------')
    lines.append(str(a * b))
    return chr(10).join(lines)

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('AIChat — школьный помощник')
        self.geometry('1100x760')
        self.settings = load(SETTINGS_PATH, {'baseURL': 'https://positionapi.top/v1', 'apiKey': '', 'selectedModel': '', 'schoolMode': True, 'schoolSubject': 'Авто', 'schoolFormat': 'Краткие ответы', 'textbooks': '', 'myStyle': '', 'systemPrompt': 'Ты — полезный ИИ-ассистент. Отвечай на русском, кратко и по делу.'})
        self.chats = load(CHATS_PATH, [])
        self.current = 0 if self.chats else -1
        self.attachments = []
        self.build_ui()
        self.refresh_chats()
        if not self.chats:
            self.new_chat()
    def build_ui(self):
        left = tk.Frame(self, width=230)
        left.pack(side='left', fill='y')
        tk.Button(left, text='Новый чат', command=self.new_chat).pack(fill='x', padx=6, pady=6)
        self.chat_list = tk.Listbox(left)
        self.chat_list.pack(fill='both', expand=True, padx=6, pady=6)
        self.chat_list.bind('<<ListboxSelect>>', self.open_chat)
        right = tk.Frame(self)
        right.pack(side='right', fill='both', expand=True)
        top = tk.Frame(right)
        top.pack(fill='x')
        self.model_var = tk.StringVar(value=self.settings.get('selectedModel', ''))
        self.model_box = ttk.Combobox(top, textvariable=self.model_var, width=32)
        self.model_box.pack(side='left', padx=4, pady=4)
        tk.Button(top, text='Модели', command=self.load_models).pack(side='left')
        tk.Button(top, text='Настройки', command=self.open_settings).pack(side='left')
        tk.Button(top, text='Инструменты', command=self.open_tools).pack(side='left')
        tk.Button(top, text='МЭШ', command=self.open_mesh).pack(side='left')
        self.view = scrolledtext.ScrolledText(right, wrap='word')
        self.view.pack(fill='both', expand=True, padx=6, pady=6)
        self.view.configure(state='disabled')
        self.attach_label = tk.Label(right, text='')
        self.attach_label.pack(fill='x')
        bottom = tk.Frame(right)
        bottom.pack(fill='x')
        self.input = tk.Text(bottom, height=3)
        self.input.pack(side='left', fill='both', expand=True, padx=4, pady=4)
        tk.Button(bottom, text='Фото', command=self.attach).pack(side='left')
        tk.Button(bottom, text='Отправить', command=self.send).pack(side='left')
    def refresh_chats(self):
        self.chat_list.delete(0, tk.END)
        for c in self.chats:
            self.chat_list.insert(tk.END, c.get('title', 'Чат'))
        self.show()
    def new_chat(self):
        self.chats.insert(0, {'title': 'Новый чат', 'messages': []})
        self.current = 0
        save(CHATS_PATH, self.chats)
        self.refresh_chats()
    def open_chat(self, event=None):
        sel = self.chat_list.curselection()
        if sel:
            self.current = sel[0]
            self.show()
    def show(self):
        self.view.configure(state='normal')
        self.view.delete('1.0', tk.END)
        if 0 <= self.current < len(self.chats):
            for m in self.chats[self.current].get('messages', []):
                who = 'Вы' if m.get('role') == 'user' else 'ИИ'
                self.view.insert(tk.END, who + ': ' + m.get('content', '') + chr(10) + chr(10))
        self.view.configure(state='disabled')
        self.view.see(tk.END)
    def load_models(self):
        def work():
            try:
                models = fetch_models(self.settings)
                self.model_box['values'] = models
                if models and not self.model_var.get():
                    self.model_var.set(models[0])
            except Exception as e:
                messagebox.showerror('Модели', str(e))
        threading.Thread(target=work, daemon=True).start()
    def attach(self):
        path = filedialog.askopenfilename(filetypes=[('Images', '*.png *.jpg *.jpeg *.webp')])
        if path:
            with open(path, 'rb') as f:
                data = base64.b64encode(f.read()).decode('ascii')
            self.attachments.append(data)
            self.attach_label.configure(text='Прикреплено фото: ' + str(len(self.attachments)))
    def send(self):
        text = self.input.get('1.0', tk.END).strip()
        if not text and not self.attachments:
            return
        if not self.model_var.get():
            messagebox.showwarning('Модель', 'Сначала выбери модель')
            return
        self.settings['selectedModel'] = self.model_var.get()
        save(SETTINGS_PATH, self.settings)
        if self.current < 0:
            self.new_chat()
        content = text if text else 'Реши задание с фото'
        self.chats[self.current]['messages'].append({'role': 'user', 'content': content})
        if len(self.chats[self.current]['messages']) == 1:
            self.chats[self.current]['title'] = content[:40]
        atts = self.attachments[:]
        self.attachments = []
        self.attach_label.configure(text='')
        self.input.delete('1.0', tk.END)
        save(CHATS_PATH, self.chats)
        self.refresh_chats()
        threading.Thread(target=self.do_send, args=(content, atts), daemon=True).start()
    def do_send(self, content, atts):
        messages = [{'role': 'system', 'content': make_prompt(self.settings, content)}]
        for m in self.chats[self.current].get('messages', [])[:-1]:
            messages.append({'role': m.get('role', 'user'), 'content': m.get('content', '')})
        if atts:
            parts = [{'type': 'text', 'text': content}]
            for a in atts:
                parts.append({'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,' + a}})
            messages.append({'role': 'user', 'content': parts})
        else:
            messages.append({'role': 'user', 'content': content})
        answer = complete(self.settings, messages)
        self.chats[self.current]['messages'].append({'role': 'assistant', 'content': answer})
        save(CHATS_PATH, self.chats)
        self.after(0, self.refresh_chats)
    def open_settings(self):
        w = tk.Toplevel(self)
        w.title('Настройки')
        w.geometry('520x560')
        fields = [('baseURL', 'API Base URL'), ('apiKey', 'API Key'), ('selectedModel', 'Модель')]
        vars = {}
        for key, label in fields:
            tk.Label(w, text=label).pack(anchor='w', padx=8)
            v = tk.StringVar(value=self.settings.get(key, ''))
            vars[key] = v
            tk.Entry(w, textvariable=v, show='*' if key == 'apiKey' else '').pack(fill='x', padx=8)
        tk.Label(w, text='Предмет').pack(anchor='w', padx=8)
        subj = ttk.Combobox(w, values=SUBJECTS)
        subj.set(self.settings.get('schoolSubject', 'Авто'))
        subj.pack(fill='x', padx=8)
        tk.Label(w, text='Формат').pack(anchor='w', padx=8)
        fmt = ttk.Combobox(w, values=FORMATS)
        fmt.set(self.settings.get('schoolFormat', 'Кратко и по делу'))
        fmt.pack(fill='x', padx=8)
        tk.Label(w, text='Учебники и тетради').pack(anchor='w', padx=8)
        books = tk.Text(w, height=3)
        books.insert('1.0', self.settings.get('textbooks', ''))
        books.pack(fill='x', padx=8)
        tk.Label(w, text='Мой стиль').pack(anchor='w', padx=8)
        style = tk.Text(w, height=3)
        style.insert('1.0', self.settings.get('myStyle', ''))
        style.pack(fill='x', padx=8)
        school = tk.BooleanVar(value=self.settings.get('schoolMode', True))
        tk.Checkbutton(w, text='Школьный режим 6 класс', variable=school).pack(anchor='w', padx=8)
        def do_save():
            for k, v in vars.items():
                self.settings[k] = v.get()
            self.settings['schoolSubject'] = subj.get()
            self.settings['schoolFormat'] = fmt.get()
            self.settings['textbooks'] = books.get('1.0', tk.END).strip()
            self.settings['myStyle'] = style.get('1.0', tk.END).strip()
            self.settings['schoolMode'] = school.get()
            self.model_var.set(self.settings.get('selectedModel', ''))
            save(SETTINGS_PATH, self.settings)
            w.destroy()
        tk.Button(w, text='Сохранить', command=do_save).pack(pady=8)
    def open_tools(self):
        w = tk.Toplevel(self)
        w.title('Школьные инструменты')
        w.geometry('560x520')
        tk.Label(w, text='Умножение в столбик').pack(anchor='w', padx=8)
        a = tk.Entry(w)
        a.pack(fill='x', padx=8)
        b = tk.Entry(w)
        b.pack(fill='x', padx=8)
        out = scrolledtext.ScrolledText(w, height=14)
        out.pack(fill='both', expand=True, padx=8, pady=8)
        def calc():
            try:
                out.delete('1.0', tk.END)
                out.insert(tk.END, column_multiply(int(a.get()), int(b.get())))
            except Exception:
                messagebox.showwarning('Столбик', 'Введи два числа')
        tk.Button(w, text='Посчитать в столбик', command=calc).pack()
        tk.Label(w, text='Формулы: S = a x b; P = 2 x (a + b); V = a x b x c; v = s / t').pack(padx=8, pady=8)
    def open_mesh(self):
        w = tk.Toplevel(self)
        w.title('МЭШ: домашка')
        w.geometry('640x560')
        tk.Label(w, text='aupd_token').pack(anchor='w', padx=8)
        token = tk.Entry(w, show='*')
        token.pack(fill='x', padx=8)
        tk.Label(w, text='ID ученика').pack(anchor='w', padx=8)
        sid = tk.Entry(w)
        sid.pack(fill='x', padx=8)
        out = scrolledtext.ScrolledText(w)
        out.pack(fill='both', expand=True, padx=8, pady=8)
        def fetch():
            import datetime
            today = datetime.date.today()
            end = today + datetime.timedelta(days=7)
            url = 'https://school.mos.ru/api/eventcalendar/v1/api/events?person_ids=' + sid.get() + '&begin_date=' + today.isoformat() + '&end_date=' + end.isoformat() + '&expand=homework,marks'
            req = urllib.request.Request(url, headers={'Cookie': 'aupd_token=' + token.get(), 'Authorization': 'Bearer ' + token.get(), 'profile-type': 'student'})
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    data = json.loads(r.read().decode('utf-8'))
                out.delete('1.0', tk.END)
                out.insert(tk.END, json.dumps(data, ensure_ascii=False, indent=2)[:8000])
            except Exception as e:
                messagebox.showerror('МЭШ', str(e))
        tk.Button(w, text='Загрузить домашку', command=lambda: threading.Thread(target=fetch, daemon=True).start()).pack()

if __name__ == '__main__':
    App().mainloop()
