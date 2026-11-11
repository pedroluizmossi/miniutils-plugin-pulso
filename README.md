# Pulso

Plugin de exemplo do MiniUtils que usa os recursos avançados dos plugins:

| O que faz | Recurso |
|---|---|
| CPU, RAM, temperatura e rede ao vivo, com um monitor de batimentos das últimas 40 leituras | `uses = ["sys"]` e `fn on_event(topic, data)` |
| Recorde de CPU e temperatura, que sobrevive a desligar e reiniciar | `store_get` / `store_set` |
| O processo culpado quando a CPU passa do limite | `uses = ["procs"]` (os processos mais pesados, iguais no Linux e no Windows) |
| IP público, a cada 10 min ou no botão ↻ | `[permissions] net = ["api.ipify.org"]` e `http_get_async` + `parse_json` |
| Conta à conversa entre mascotes quem causou o pico | `fact("strain", processo, pct)` |
| Monitor, barras e quadros num arquivo à parte e um coração que bate a cada leitura | `ui/grafico.slint` e `assets/coracao.png` |

Opções (Configurações > Apps > Pulso): a partir de quantos % de CPU vale como pico (padrão
85) e se mostra o IP público (desligado, o plugin não usa a rede).

## Permissões

- rede: `api.ipify.org`
- lê: `sys` (CPU, memória, temperatura, rede e discos) e `procs` (os processos que mais
  usam CPU e memória)

Não executa nenhum programa.

## Instalar

Pela loja do MiniUtils (Configurações > Loja de plugins) ou:

```sh
miniutils --instalar io.github.pedroluizmossi.pulso
```

Precisa de um MiniUtils com o provedor `procs` (o mesmo que traz `miniutils --version`);
uma versão anterior recusa a instalação.

## Desenvolver

```sh
git clone https://github.com/pedroluizmossi/miniutils-plugin-pulso
miniutils --plugin-dev miniutils-plugin-pulso
```

O plugin entra ligado na primeira página e recarrega ao salvar; os erros da tela e do
script saem no terminal.

## Versões

- **0.3.0**: o culpado de um pico vem do provedor `procs` do MiniUtils em vez do `ps`:
  funciona também no Windows, e o plugin não executa mais nenhum programa.
- **0.2.0**: visual no estilo dos Sinais vitais: cartão com a borda no humor, mascote com
  aura, barra de CPU em segmentos, monitor de batimentos com grade e linha do limite, e
  quadros de RAM, temperatura e rede. Responsivo: numa célula baixa, os quadros somem.
- **0.1.0**: primeira versão.

Licença MIT.
