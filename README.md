# dehydrated-clouddns
Dehydrated hook for solving ACME challenges via [CloudDNS API][clouddns].

## Features
- Solve ACME challenge in dehydrated using [CloudDNS API][clouddns].
- Generate wildcard certificates.

## Installation
Just clone the repository:

`git clone https://github.com/vshosting/dehydrated-clouddns.git`

## Usage
To use this plugin with dehydrated, you need to export your CloudDNS credentials (email, password, client id) and register it with dehydrated as a hook.

```bash
export CLOUDDNS_CLIENT_ID="myclientid"
export CLOUDDNS_EMAIL="my@email.com"
export CLOUDDNS_PASSWORD="mysecretpassword"
dehydrated --cron --challenge dns-01 --hook dehydrated-clouddns.sh --domain example.org
```

## Contributing
For information on how to contribute to the project, please check the [Contributor's Guide][contributing].

## Contact
[bambuch@vshosting.cz](mailto:bambuch@vshosting.cz)

## License
MIT License

## Credits
This package was created with [Cookiecutter][cookiecutter].

[clouddns]: https://github.com/vshosting/clouddns
[contributing]: https://github.com/vshosting/dehydrated-clouddns/blob/master/CONTRIBUTING.md
[cookiecutter]: https://github.com/audreyr/cookiecutter
