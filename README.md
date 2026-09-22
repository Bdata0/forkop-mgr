# 🎛️ Forkop Control Center (`forkop-mgr`)

[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.x-blue?logo=openwrt)](https://openwrt.org/)
[![Shell](https://img.shields.io/badge/Shell-POSIX%20sh-lightgrey?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Architecture](https://img.shields.io/badge/Architecture-ARM64%20%2F%20AArch64-orange)](https://openwrt.org/docs/techref/targets)

**Универсальный инструмент автоматизации, обслуживания и аварийного восстановления для связки Forkop + Sing-Box Extended + NetBird на роутерах с OpenWrt 25.x.**

Специально оптимизирован для устройств с компактным разделом `/overlay`, включая **Xiaomi Redmi Router AX6000** со штатной разметкой.

**Languages:** 🇷🇺 Русский · [🇬🇧 English](#-english)

---

# 🇷🇺 Русский

## 📌 О проекте

`forkop-mgr` — консольный менеджер для безопасного обслуживания роутера, на котором одновременно используются:

- **Forkop** — управление прокси/сетевыми функциями;
- **Sing-Box Extended** — сетевое ядро;
- **NetBird** — mesh/VPN-туннель;
- **DoH** — DNS over HTTPS;
- **OpenWrt 25.x** с пакетным менеджером `apk`.

Основная задача проекта — сделать операции обновления, резервного копирования и восстановления максимально безопасными даже на роутерах с очень ограниченным свободным местом во flash-памяти.

---

## 🌟 Основные возможности

### ⚡ Управление ядром Sing-Box Extended

- Интерактивный выбор одной из **3 последних версий** из GitHub.
- Скачивание официальных **UPX-сжатых** сборок.
- Экономия места во flash-памяти: примерно **21 МБ вместо ~100 МБ**.
- Умный расчёт свободного места с учётом замены текущего файла.
- Все операции распаковки и проверки выполняются в **ОЗУ (`/tmp`)**.
- Создание временного снимка текущего ядра перед заменой.
- **Автоматический rollback** при ошибках.
- Проверка нового ядра через `sing-box check`.
- Синхронизация версии с базой пакетов `apk` и кэшем Forkop.
- Актуальное отображение версии в LuCI.

### 🔄 Безопасное обновление Forkop

- Прямое скачивание и установка:
  - `forkop.apk`;
  - `luci-app-forkop.apk`.
- Обход ограничения официального установщика Forkop в **15 МБ свободного места**.
- Пакеты занимают около **500 КБ**.
- Автоматическая разблокировка базы `/etc/apk/world`.
- Сохранение пользовательской конфигурации `/etc/config/forkop`.
- Установка напрямую через `apk add`.

### 🛡️ Защита NetBird (`wt0`) и предотвращение DNS-петель

Скрипт предотвращает взаимную блокировку компонентов:

> DoH зависит от NetBird, а NetBird не может подключиться к серверу управления без DNS.

Для этого:

1. Forkop временно останавливается.
2. Запускается NetBird.
3. Скрипт ожидает появления `wt0`.
4. Проверяется получение IP-адреса.
5. Только после этого запускается Forkop.

### 📦 Полное резервное копирование и восстановление

Бэкап может включать:

- конфигурацию Forkop;
- сертификаты;
- ключи и конфигурацию NetBird;
- DoH;
- DHCP;
- Cron;
- пользовательские скрипты и настройки.

Бэкапы сохраняются:

- в `/etc/forkop_backups/` — постоянное хранилище;
- в `/tmp/` — для удобного скачивания на компьютер.

Перед восстановлением создаётся снимок текущего состояния. При ошибке выполняется **автоматический rollback**.

### 🩺 Диагностика и безопасный перезапуск

- Мягкий перезапуск служб в правильном порядке.
- Предотвращение зависания сетевого стека.
- Перезапуск NetBird с ожиданием `wt0`.
- Принудительное обновление списков доменов и подписок.
- Восстановление после временного разрыва туннеля или DNS-петли.

---

# 🏗️ Архитектура

Основная идея `forkop-mgr` — не просто запускать команды, а контролировать зависимости между сервисами.

```text
                         ┌──────────────────────┐
                         │     OpenWrt 25.x     │
                         │      Router          │
                         └──────────┬───────────┘
                                    │
                           ┌────────▼────────┐
                           │   forkop-mgr    │
                           │ Control Center  │
                           └────────┬────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ▼                     ▼                     ▼
       ┌─────────────┐        ┌─────────────┐      ┌─────────────┐
       │    Forkop   │──────▶ │  DoH DNS    │     │  Sing-Box   │
       └──────┬──────┘        └─────┬───────┘      │  Extended   │
              │                     │              └─────────────┘
              │                     │
              │              DNS dependency
              │                     │
              │                     ▼
              │               ┌─────────────┐
              └─────────────▶│   NetBird   │
                              │     wt0     │
                              └──────┬──────┘
                                     │
                                     ▼
                             NetBird Management
```

### Почему важен порядок запуска?

При определённой конфигурации может возникнуть цикл:

```text
        ┌─────────────┐
        │    Forkop   │
        └──────┬──────┘
               │
               ▼
            DoH DNS
               │
               ▼
          NetBird wt0
               │
               ▼
       Management Server
               │
               │ требует DNS
               └───────────────┐
                               ▼
                            DoH DNS
```

Если `wt0` ещё не поднят, NetBird может не разрешить адрес management-сервера.

Если при этом Forkop уже перенаправил DNS через DoH, DNS тоже может стать недоступным.

`forkop-mgr` разрывает этот цикл правильной последовательностью:

```text
Forkop STOP
    │
    ▼
NetBird START
    │
    ▼
wait for wt0
    │
    ▼
check IP address
    │
    ▼
Forkop START
    │
    ▼
refresh lists / subscriptions
```

---

# 🔄 Безопасное обновление Sing-Box

Обновление ядра выполняется через временную область `/tmp`, чтобы минимизировать риск повреждения установленного бинарника.

```text
          GitHub Release
                │
                ▼
        Download to /tmp
                │
                ▼
          UPX / unpack
                │
                ▼
        Validate binary
                │
                ▼
       sing-box check
                │
          ┌─────┴─────┐
          │           │
        ERROR          OK
          │           │
          ▼           ▼
       cleanup    RAM snapshot
                      │
                      ▼
                replace binary
                      │
                      ▼
                post-check
                  /      \
                 /        \
              ERROR        OK
                │           │
                ▼           ▼
             ROLLBACK      DONE
```

---

## 🚀 Установка и обновление скрипта

Для чистой установки на новый роутер или обновления уже установленного скрипта выполните в SSH:

```sh
sh -c "$(curl -skLf https://cdn.jsdelivr.net/gh/Bdata0/forkop-mgr@main/install.sh 2>/dev/null || wget -q --no-check-certificate -O- https://cdn.jsdelivr.net/gh/Bdata0/forkop-mgr@main/install.sh)"
```

Запуск:

```sh
forkop-mgr
```

> Если репозиторий/ветка отличаются от `Bdata0/forkop-mgr/main`, замените URL на актуальный.

---

# 🖥️ Интерфейс консольного меню

При запуске скрипт автоматически считывает текущий статус системы:

```text
========================================================
             FORKOP CONTROL CENTER
========================================================
  Устройство : Xiaomi AX6000 (OpenWrt 25.12)
  Ядро       : Sing-Box 1.14.1-extended-2.7.2
  Forkop     : 1.0.5
  Туннель    : NetBird UP (wt0)
========================================================
  1) Управление ядром Sing-Box (Extended + UPX)
  2) Обновление самого Forkop (прямая установка APK)
  3) Резервное копирование и Восстановление
  4) Быстрый безопасный перезапуск всех служб
  0) Выход
========================================================
Выберите раздел [0-4]:
```

---

# 📖 Подробное описание

## 1. Управление ядром Sing-Box

Скрипт получает последние релизы из репозитория:

**[shtorm-7/sing-box-extended](https://github.com/shtorm-7/sing-box-extended)**

Пользователь может выбрать одну из трёх последних версий.

Все операции выполняются максимально безопасно:

1. Получение списка последних релизов.
2. Выбор версии.
3. Проверка свободного места.
4. Скачивание сборки в `/tmp`.
5. Распаковка в ОЗУ.
6. Проверка бинарного файла.
7. Проверка конфигурации через `sing-box check`.
8. Создание резервной копии текущего ядра.
9. Замена бинарного файла.
10. Синхронизация версии с `apk` и Forkop.

При ошибке выполняется автоматический **rollback**.

---

## 2. Обновление Forkop

Релизы берутся из:

**[ushan0v/forkop](https://github.com/ushan0v/forkop)**

Пакеты устанавливаются напрямую через `apk`:

```sh
apk add forkop.apk luci-app-forkop.apk
```

Это позволяет избежать ограничения стандартного установщика, требующего значительный запас свободного места.

Пользовательская конфигурация:

```text
/etc/config/forkop
```

После обновления дополнительно контролируется NetBird:

```text
Forkop STOP
    ↓
NetBird START
    ↓
wait for wt0
    ↓
check IP
    ↓
Forkop START
    ↓
update lists
```

---

## 3. Резервное копирование и восстановление

### Создание бэкапа

В архив могут входить:

```text
Forkop
NetBird
DoH
DHCP
Cron
scripts
certificates
NetBird keys
```

Постоянное хранилище:

```text
/etc/forkop_backups/
```

Временный файл для скачивания:

```text
/tmp/
```

### Скачивание на ПК

Linux / macOS / PowerShell:

```powershell
scp -O root@192.168.11.1:/tmp/forkop_backup_*.tar.gz .
```

> Замените `192.168.11.1` на IP-адрес вашего роутера при необходимости.

### Восстановление

Перед восстановлением:

```text
Current state
     │
     ▼
RAM snapshot
     │
     ▼
Restore backup
     │
     ▼
Validation
   ┌─┴─┐
   │   │
  OK ERROR
   │   │
   ▼   ▼
 DONE ROLLBACK
```

---

## 4. Быстрый безопасный перезапуск

Используйте этот режим, если:

- NetBird временно потерял соединение;
- перестал подниматься `wt0`;
- возникла DNS-петля;
- сетевой стек оказался в некорректном состоянии.

Последовательность:

1. Остановить Forkop.
2. Восстановить возможность прямого DNS-резолва.
3. Перезапустить NetBird.
4. Дождаться `wt0`.
5. Проверить IP-адрес.
6. Запустить Forkop.
7. Обновить списки блокировок и подписки.

---

# ⚙️ Системные требования

| Компонент | Требование |
|---|---|
| **ОС** | OpenWrt 25.x |
| **Package Manager** | `apk` |
| **Архитектура** | ARM64 / AArch64 |
| **SoC** | MediaTek MT7986A и аналогичные |
| **Shell** | POSIX `sh` |
| **Необходимые пакеты** | `curl`, `tar`, `ca-certificates` |

Проект ориентирован прежде всего на роутеры с ограниченным объёмом `/overlay`.

---

# ⚠️ Безопасность

## 🔐 Ключи NetBird

Архивы резервных копий могут содержать **приватные ключи и данные авторизации NetBird**, включая:

```text
/etc/netbird/config.json
```

Поэтому:

- **не публикуйте `.tar.gz` бэкапы в GitHub;**
- не размещайте их в публичных файловых хранилищах;
- храните бэкапы в защищённом месте;
- не передавайте архивы третьим лицам без необходимости.

### Восстановление существующего роутера

Для замены вышедшего из строя роутера и сохранения существующей конфигурации NetBird используйте полный бэкап вместе с соответствующей конфигурацией `/etc/netbird/`.

### Новый независимый роутер

Если создаётся новый независимый роутер, **не восстанавливайте старые NetBird-ключи**.

Используйте новый **Setup Key** для регистрации нового узла.

---

# 🗂️ Структура проекта

```text
forkop-mgr/
├── forkop-mgr
└── README.md
```

После установки основной скрипт находится в:

```text
/usr/bin/forkop-mgr
```

---

# 🤝 Contributing

Предложения, исправления и улучшения приветствуются.

Если вы нашли проблему:

1. Проверьте, что она воспроизводится на актуальной версии OpenWrt.
2. Сохраните вывод `forkop-mgr`.
3. Создайте [Issue](https://github.com/Bdata0/forkop-mgr/issues).
4. По возможности приложите логи без приватных ключей, токенов и конфиденциальных данных.

Pull Requests также приветствуются.

---

# 📜 License

```text
MIT License
```

---

# ⭐ Поддержка проекта

Если `forkop-mgr` оказался полезен, поставьте ⭐ репозиторию — это помогает проекту развиваться.

---

# 🇬🇧 English

## 📌 About

`forkop-mgr` is a console-based management and recovery utility for routers running:

- **Forkop**;
- **Sing-Box Extended**;
- **NetBird**;
- **DoH DNS**;
- **OpenWrt 25.x** with the `apk` package manager.

The project is designed with **small `/overlay` partitions** in mind, making updates and recovery safer on devices with limited flash storage.

---

## 🌟 Features

### ⚡ Sing-Box Extended management

- Interactive selection of the **3 latest releases** from GitHub.
- Official **UPX-compressed** builds.
- Significantly reduced flash usage: about **21 MB instead of ~100 MB**.
- Smart free-space calculation.
- Temporary operations performed in **RAM (`/tmp`)**.
- RAM snapshot before replacing the current binary.
- Automatic **rollback** on failure.
- Configuration validation using `sing-box check`.
- Synchronization with `apk` package metadata and Forkop cache.
- Accurate version information in LuCI.

### 🔄 Safe Forkop updates

- Direct installation of:
  - `forkop.apk`;
  - `luci-app-forkop.apk`.
- Bypasses the official installer **15 MB free-space requirement**.
- Packages are only around **500 KB**.
- Automatic handling of `/etc/apk/world`.
- Preserves `/etc/config/forkop`.
- Installs packages directly with `apk add`.

### 🛡️ NetBird (`wt0`) protection

The manager prevents circular dependencies between DNS, Forkop and NetBird.

Typical startup sequence:

```text
Forkop STOP
    ↓
NetBird START
    ↓
wait for wt0
    ↓
check IP address
    ↓
Forkop START
    ↓
refresh lists
```

### 📦 Full backup and restore

Backups can include:

- Forkop configuration;
- NetBird configuration and keys;
- certificates;
- DoH settings;
- DHCP configuration;
- Cron jobs;
- scripts and related settings.

Backups are stored in:

```text
/etc/forkop_backups/
```

and temporarily in:

```text
/tmp/
```

A RAM snapshot is created before restoring a backup, allowing an automatic rollback if the restored configuration fails.

---

# 🏗️ Architecture

```text
                         ┌──────────────────────┐
                         │     OpenWrt 25.x     │
                         │        Router        │
                         └──────────┬───────────┘
                                    │
                           ┌────────▼────────┐
                           │   forkop-mgr    │
                           │ Control Center  │
                           └────────┬────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ▼                     ▼                     ▼
       ┌─────────────┐        ┌─────────────┐       ┌─────────────┐
       │    Forkop   │──────▶│    DoH DNS  │       │  Sing-Box   │
       └──────┬──────┘        └─────┬───────┘       │  Extended   │
              │                     │               └─────────────┘
              │                     │
              │              DNS dependency
              │                     │
              │                     ▼
              │               ┌─────────────┐
              └─────────────▶│   NetBird   │
                              │     wt0     │
                              └──────┬──────┘
                                     │
                                     ▼
                             NetBird Management
```

The manager controls the service order to avoid DNS/NetBird startup loops.

---

# 🔄 Safe Sing-Box update flow

```text
          GitHub Release
                │
                ▼
        Download to /tmp
                │
                ▼
          UPX / unpack
                │
                ▼
        Validate binary
                │
                ▼
       sing-box check
                │
          ┌─────┴─────┐
          │           │
        ERROR          OK
          │           │
          ▼           ▼
       cleanup    RAM snapshot
                      │
                      ▼
                replace binary
                      │
                      ▼
                post-check
                  /      \
                 /        \
              ERROR        OK
                │           │
                ▼           ▼
             ROLLBACK      DONE
```

---

# 🚀 Quick Start

## Install and update script

Connect to the router over SSH and run:

```sh
sh -c "$(curl -skLf https://cdn.jsdelivr.net/gh/Bdata0/forkop-mgr@main/install.sh 2>/dev/null || wget -q --no-check-certificate -O- https://cdn.jsdelivr.net/gh/Bdata0/forkop-mgr@main/install.sh)"
```

Run:

```sh
forkop-mgr
```

> If your repository or branch is different, replace the URL accordingly.

---

# 🖥️ Console interface

Example:

```text
========================================================
             FORKOP CONTROL CENTER
========================================================
  Device     : Xiaomi AX6000 (OpenWrt 25.12)
  Core       : Sing-Box 1.14.1-extended-2.7.2
  Forkop     : 1.0.5
  Tunnel     : NetBird UP (wt0)
========================================================
  1) Sing-Box Core Management (Extended + UPX)
  2) Forkop Update (Direct APK Installation)
  3) Backup and Restore
  4) Safe Service Restart
  0) Exit
========================================================
Select [0-4]:
```

---

# ⚙️ Requirements

| Component | Requirement |
|---|---|
| **OS** | OpenWrt 25.x |
| **Package manager** | `apk` |
| **Architecture** | ARM64 / AArch64 |
| **SoC** | MediaTek MT7986A and similar |
| **Shell** | POSIX `sh` |
| **Required packages** | `curl`, `tar`, `ca-certificates` |

---

# ⚠️ Security

## 🔐 NetBird private keys

Backup archives may contain **private NetBird authentication data**, including:

```text
/etc/netbird/config.json
```

Never publish these archives to a public repository.

Keep backups secure and do not share them unless necessary.

### Existing router replacement

When replacing a failed router and preserving its existing NetBird identity, restore the full backup including the relevant `/etc/netbird/` configuration.

### New independent router

For a new independent router, **do not restore the old NetBird keys**.

Register the new node using a new **Setup Key** instead.

---

# 🗂️ Project structure

```text
forkop-mgr/
├── forkop-mgr
└── README.md
```

After installation:

```text
/usr/bin/forkop-mgr
```

---

# 🤝 Contributing

Bug reports, improvements and Pull Requests are welcome.

When reporting an issue:

1. Make sure it can be reproduced on a current OpenWrt version.
2. Include relevant `forkop-mgr` output.
3. Open an [Issue](https://github.com/Bdata0/forkop-mgr/issues).
4. Remove private keys, tokens and sensitive configuration data from logs before sharing them.

---

# 📜 License

```text
MIT License
```

---

# ⭐ Support

If `forkop-mgr` is useful to you, consider giving the repository a ⭐.

It helps the project grow.
