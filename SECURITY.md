# Security policy

WinMasterBlocker is a single batch script that runs locally and only invokes built-in Windows commands (`net`, `netsh`, `powershell`). It does not install services, drivers, scheduled tasks, or auto-update components. There is no network surface to exploit.

## Reporting

If you find a way that the script can be coerced into adding firewall rules against a target an attacker controls, dropping privileges incorrectly, or otherwise behaving in a way that could harm the user, please open a GitHub issue with the `security` label, or contact the author through their GitHub profile.

## Out of scope

- Reports that "blocking these applications might prevent legitimate updates". That is the intended behaviour. See the README FAQ.
- Reports that the script requires Administrator. `netsh advfirewall` requires it; this is a Windows requirement, not a design choice.
- Reports that the firewall rules can be removed by an Administrator. Yes, any user with Administrator can edit firewall rules. This script is one of many such users.
