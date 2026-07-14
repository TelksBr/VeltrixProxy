# VeltrixProxy

Repositório de releases dos binários do **VTProxy**.

Os arquivos são publicados automaticamente pelo CI/CD.

## Instalação

```bash
curl -fsSL https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh | bash
```

## Atualizar

```bash
curl -fsSL https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh | bash -s -- --update --yes
```

## Reinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh | bash -s -- --reinstall --latest --yes
```

## Menu

Após instalar, execute:

```bash
vt
```

(`main` e `proto` são symlinks para `vt` na instalação padrão.)
