# Pulso

Plugin de exemplo do MiniUtils que usa os recursos avançados dos plugins:

| O que faz | Recurso |
|---|---|
| CPU, temperatura e RAM ao vivo, com gráfico das últimas 30 leituras | `uses = ["sys"]` e `fn on_event(topic, data)` |
| Recorde de CPU e temperatura, que sobrevive a desligar e reiniciar | `store_get` / `store_set` |
| O processo culpado quando a CPU passa do limite | `run_async(["ps", …], "achou_culpado")` |
| IP público, a cada 10 min ou no botão ↻ | `[permissions] net = ["api.ipify.org"]` e `http_get_async` + `parse_json` |
| Conta à conversa entre mascotes quem causou o pico | `fact("strain", processo, pct)` |
| Gráfico num arquivo à parte e um coração que bate a cada leitura | `ui/grafico.slint` e `assets/coracao.png` |

Opções (Configurações > Apps > Pulso): a partir de quantos % de CPU vale como pico (padrão
85) e se mostra o IP público (desligado, o plugin não usa a rede).

## Permissões

- executa: `ps`
- rede: `api.ipify.org`
- lê: `sys` (CPU, memória, temperatura, rede e discos)

## Instalar

Pela loja do MiniUtils (Configurações > Loja de plugins) ou:

```sh
miniutils --instalar io.github.pedroluizmossi.pulso
```

Precisa de um MiniUtils com os recursos avançados de plugin (`uses`, `net`, `run_async`,
`ui/` e `assets/`); uma versão anterior recusa a instalação.

## Desenvolver

```sh
git clone https://github.com/pedroluizmossi/miniutils-plugin-pulso
miniutils --plugin-dev miniutils-plugin-pulso
```

O plugin entra ligado na primeira página e recarrega ao salvar; os erros da tela e do
script saem no terminal.

Licença MIT.
