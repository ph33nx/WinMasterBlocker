### 🟢🔵🔴 Contributions welcome in expanding the list of vendors and installation paths!

👉 If you know additional paths for app vendors or have information on other vendors, please consider contributing. (See the **Contributing** section below for details.)

# 🔥 WinMasterBlocker 🔥

### Your all-in-one firewall control script for blocking Adobe, Corel, Autodesk, Maxon and more from phoning-home! 💻🚫

## What is this?

Welcome to **WinMasterBlocker**—a nifty little batch script that slaps firewall rules on apps you probably don’t want connecting to the internet (like Adobe, Autodesk, Corel, Maxon and others). It’s your no-fuss way to get peace and quiet from those phoning-home apps. 🚫📡

## !IMP: Only Windows inbuilt commands & firewall cli is used to block the apps from internet access, NO third party tools or solutions are used for this script's functionality.

---

## Quick Start

To run the script, simply download `WinMasterBlocker.bat` and **double-click** it or run the following command from the command line **as administrator**:

```bash
WinMasterBlocker.bat
```

---

## Usage 📜

### Running the script:

1. **Make sure you run this as admin!** It won't work otherwise _(netsh requires it)_. We’ll prompt you if you forget, don’t worry. 😎
2. **Double-click or run from the command line**

### Options in the menu:

- **Block rules** for Adobe, Corel, Autodesk, etc.
- **Remove firewall rules** (just the ones we added, don’t worry 😉).
- You can pick whether to block **inbound**, **outbound**, or both kinds of traffic. Customizable and clean. 💪

---

## Contributing 👾

We love contributions, PRs, and feature requests! If you’re one of those who likes to tinker and hack on scripts, here’s how you can get involved:

### Steps to contribute:

1. **Fork it** 🍴 – You know the drill. Fork this repo.
2. **Clone it** 🛠️ – Get the code to your local:
   ```bash
   git clone https://github.com/ph33nx/WinMasterBlocker
   ```
3. **Create a branch** 🌿 – New features? Fixes? Start a new branch:
   ```bash
   git checkout -b my-cool-feature
   ```
4. **Add your magic** ✨ – Modify `WinMasterBlocker.bat` or enhance the `README.md`. Make sure your changes are 💯 legit.
5. **Push your branch** 🚀 – Send it back up:
   ```bash
   git push origin my-cool-feature
   ```
6. **Submit a Pull Request (PR)** 🤙

### Want to add more apps to block? 🛑

Feel free to throw in more providers. Just add the app to the `providers[]` and `paths[]` arrays in the script. Got new paths for a provider? Add them in there too! We’re open to adding pretty much anything (the bigger the blacklist, the better). 💣

```batch
:: Add new provider paths here
set "vendors[7]=NewApp"
set "paths[7]=C:\Program Files\NewApp;C:\Program Files (x86)\NewApp"
```

### Checklist before sending that PR 🚧:

- Make sure the script **runs on your machine** before submitting. Nobody likes broken code. 🛠️
- Follow the existing format for adding new providers or paths.
- Respect the 💀 rule: **no hard-breaking changes**.

---

## License ⚖️

MIT License – this means you can do pretty much anything with this, but we’d love a shout-out if you find it useful. 🎉

---

## Contact 📫

- **Author:** [ph33nx](https://github.com/ph33nx)
- **Current Repo:** [WinMasterBlocker](https://github.com/ph33nx/WinMasterBlocker)
- **Contributions welcomed!** - Especially for app vendors and their install locations.

---

Feel free to copy, edit, or just stare at the code. 😎
