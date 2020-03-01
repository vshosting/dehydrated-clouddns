# dehydrated-clouddns
Dehydrated hook for solving ACME challenges via [CloudDNS API][clouddns]

## Features
- Solve ACME challenge in dehydrated using [CloudDNS API][clouddns]

## Installation
Just clone the repository:

`git clone https://gitlab.com/radek-sprta/dehydrated-clouddns`

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
[sprta@vshosting.cz](mailto:sprta@vshosting.cz)

## License
MIT License

## Credits
This package was created with [Cookiecutter][cookiecutter].

[clouddns]: https://github.com/vshosting/clouddns
[contributing]: https://gitlab.com/radek-sprta/dehydrated-clouddns/blob/master/CONTRIBUTING.md
[cookiecutter]: https://github.com/audreyr/cookiecutter
