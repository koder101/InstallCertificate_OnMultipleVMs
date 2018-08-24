
<p align="right">
User guide and description
</p>

## PowerShell script to automate the installation of certificate on multiple domain joined VMs.


## Release Notes

[Located at github.com/koder101/InstallCertificate_OnMultipleVMs](https://github.com/koder101/InstallCertificate_OnMultipleVMs/)

## Features

- Unattended installation of certificates on domain joined machines/servers.  
- Includes the validation post certificate installation.
- Password protected `.pfx` certificates can be installed.
- Generates the log of installation activity and also includes any failures.


## Quick Start

1. Clone the project to your local.
2. Open and configure the `InstallCertificate.ps1` file.
3. Only configure values under the headers `VARIABLES to configure`.
4. Run the Script and provide the certificate password on run time.
5. Check for the messages on screen and in the logs having name `cert-bulkimport_yyyy-MM-dd_HH-mm-ss.log` and `cert-bulkimport_yyyy-MM-dd_HH-mm-ss.csv`.





## Important Note:

1. All the machines should be domain joined.
2. The current supported certificate is `.pfx` with password.
3. It uses `PsExec.exe` (32-bit) to trigger the remote script. If facing issues, try with `PsExec64.exe` (64-bit) version [available here](https://docs.microsoft.com/en-us/sysinternals/downloads/pstools/)


## Contributing

Contributions are welcome!

1. Check for open issues or open a fresh issue to start a discussion around a feature idea or a bug.
2. Fork the repository to start making your changes to the master branch (or branch off of it).
3. I recommend to prepare a test which shows that the bug was fixed or that the feature works as expected.
4. Send a pull request and bug the maintainer until it gets merged and published. :smiley:

## Contact

Have some questions? Found a bug? Create [new issue](https://github.com/koder101/InstallCertificate_OnMultipleVMs/issues/new).

## License

This tool is released under the MIT license. See [LICENSE](LICENSE) for details.

