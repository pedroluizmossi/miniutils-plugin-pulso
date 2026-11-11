// Lógica do plugin "Pulso". Roda isolado, só com a API do MiniUtils:
// - on_event: as leituras dos provedores "sys" e "procs" (uses no manifesto);
// - store_get/store_set: o recorde, guardado entre execuções;
// - procs: o processo culpado num pico (igual no Linux e no Windows, sem rodar programa);
// - http_get_async + parse_json: o IP público (só api.ipify.org, de [permissions] net);
// - fact: conta à conversa entre mascotes quem causou o pico.

fn start() {
    this.cpu = [];
    this.alto = false;
    this.culpado = "";
    this.ultimo_culpado = 0;
    this.batida = false;
    this.temp_aviso = false;
    // altura do quadro do monitor para a largura 1000 (a tela avisa a dela)
    this.altura = 100.0;
    this.aplica_opcoes();
    this.mostra_recorde();
    this.busca_ip();
}

// a cada 10 min (every no manifesto): o IP público pode mudar
fn tick() {
    this.busca_ip();
}

fn action(name, arg) {
    if name == "ip" {
        ui("ip", "…");
        this.busca_ip();
    } else if name == "monitor" {
        let h = if arg.len() > 0 { parse_float(arg) } else { 0.0 };
        if h > 1.0 {
            this.altura = h;
            this.desenha();
        }
    }
}

fn settings() {
    this.aplica_opcoes();
    this.busca_ip();
}

fn aplica_opcoes() {
    this.limite = setting("limite").to_float();
    ui("limite", this.limite);
    ui("mostra-ip", setting("ip"));
}

fn on_event(topic, data) {
    if topic == "procs" {
        this.acha_culpado(data);
        return;
    }
    if topic != "sys" {
        return;
    }
    let cpu = data.cpu;
    let temp = data.cpu_temp;

    // o monitor: as últimas 40 leituras
    this.cpu.push(cpu);
    if this.cpu.len() > 40 {
        this.cpu.remove(0);
    }
    this.batida = !this.batida;
    ui("batida", this.batida);
    ui("cpu", cpu);
    ui("cpu-texto", `${cpu.round().to_int()}%`);
    this.desenha();

    // RAM
    let total = data.mem_total.to_float();
    let usada = data.mem_used.to_float();
    let ram = if total > 0.0 { usada * 100.0 / total } else { 0.0 };
    ui("ram", ram);
    ui("ram-texto", `${ram.round().to_int()}%`);
    ui("ram-nota", `${gib(usada)} / ${gib(total)} G`);

    // temperatura (0 = sem sensor)
    ui("temp", temp);
    ui("temp-texto", if temp > 0.0 { `${temp.round().to_int()} °C` } else { "—" });
    ui("temp-nota", if temp > 0.0 { "" } else { "sem sensor" });

    // rede
    ui("rede-baixa", "↓ " + taxa(data.net_rx));
    ui("rede-sobe", "↑ " + taxa(data.net_tx));

    this.guarda_recorde(cpu, temp);

    // pico (o culpado vem na próxima leitura de "procs"); sai do pico só 10 pontos abaixo
    if cpu >= this.limite {
        this.alto = true;
    } else if this.alto && cpu < this.limite - 10.0 {
        this.alto = false;
        this.culpado = "";
    }

    // temperatura crítica: alarme e um aviso só (até esfriar)
    let quente = temp >= 90.0;
    if quente && !this.temp_aviso {
        notify("Pulso", `CPU a ${temp.round().to_int()} °C`);
    }
    this.temp_aviso = quente;

    ui("pico", this.alto || quente);
    let estado = if quente {
        "quente demais!"
    } else if this.alto {
        if this.culpado != "" { "pico: " + this.culpado } else { "pico de CPU…" }
    } else if cpu >= 30.0 {
        "trabalhando"
    } else {
        "tudo calmo"
    };
    ui("estado", estado);
    summary(`CPU ${cpu.round().to_int()}% · RAM ${ram.round().to_int()}%`);
    mood(if quente { "alarm" } else if this.alto { "busy" } else if cpu >= 30.0 { "happy" } else { "idle" });
}

// a linha e a área do monitor, na proporção que a tela avisou
fn desenha() {
    let linha = caminho(this.cpu, this.altura);
    ui("altura", this.altura);
    ui("linha", linha);
    // a área desce da ponta direita até a base e volta pela base até o início da linha
    let n = this.cpu.len();
    let x0 = if n <= 1 { 0 } else { (1000.0 - (n - 1).to_float() * 1000.0 / 39.0).round().to_int() };
    let base = this.altura.round().to_int();
    ui("area", if linha == "" { "" } else { linha + ` L 1000 ${base} L ${x0} ${base} Z` });
}

// leituras (0 a 100) -> caminho SVG num quadro 1000×h, encostado à direita
fn caminho(v, h) {
    let n = v.len();
    if n == 0 {
        return "";
    }
    let passo = 1000.0 / 39.0;
    let x0 = 1000.0 - (n - 1).to_float() * passo;
    let s = "";
    for i in 0..n {
        let x = if n == 1 { 0.0 } else { x0 + i.to_float() * passo };
        let y = h * (0.98 - v[i].max(0.0).min(100.0) * 0.0096);
        s += if i == 0 { "M " } else { " L " };
        s += `${x.round().to_int()} ${y.round().to_int()}`;
    }
    if n == 1 {
        s += ` L 1000 ${(h * (0.98 - v[0] * 0.0096)).round().to_int()}`;
    }
    s
}

// bytes -> "4.5" (GiB, uma casa)
fn gib(b) {
    let g = (b / 1073741824.0 * 10.0).round() / 10.0;
    g.to_string()
}

// bytes/s -> "1.2 MB/s", "30 KB/s"
fn taxa(b) {
    if b >= 1000000.0 {
        `${((b / 100000.0).round() / 10.0).to_string()} MB/s`
    } else if b >= 1000.0 {
        `${(b / 1000.0).round().to_int()} KB/s`
    } else {
        `${b.round().to_int()} B/s`
    }
}

// num pico, o processo que mais usa CPU (no máximo a cada 30 s). `cpu` é em % da
// máquina toda, como a leitura de "sys".
fn acha_culpado(data) {
    if !this.alto || data.by_cpu.len() == 0 || now() - this.ultimo_culpado < 30 {
        return;
    }
    let p = data.by_cpu[0];
    // primeira leitura do provedor: tudo em 0
    if p.cpu < 1.0 {
        return;
    }
    this.ultimo_culpado = now();
    this.culpado = `${p.name} (${p.cpu.round().to_int()}%)`;
    ui("estado", "pico: " + this.culpado);
    // a mascote conta à conversa quem foi (o host já conta a mudança de humor)
    fact("strain", p.name, p.cpu);
}

fn guarda_recorde(cpu, temp) {
    let rec = store_get("recorde");
    if rec == () {
        rec = #{ cpu: 0.0, cpu_em: 0, temp: 0.0, temp_em: 0 };
    }
    let mudou = false;
    if cpu > rec.cpu {
        rec.cpu = cpu;
        rec.cpu_em = now();
        mudou = true;
    }
    if temp > rec.temp {
        rec.temp = temp;
        rec.temp_em = now();
        mudou = true;
    }
    if mudou {
        store_set("recorde", rec);
        this.mostra_recorde();
    }
}

fn mostra_recorde() {
    let rec = store_get("recorde");
    if rec == () {
        ui("recorde", "—");
        return;
    }
    let texto = `${rec.cpu.round().to_int()}% ${quando(rec.cpu_em)}`;
    if rec.temp > 0.0 {
        texto += ` · ${rec.temp.round().to_int()} °C ${quando(rec.temp_em)}`;
    }
    ui("recorde", texto);
}

// "agora", "há 5 min", "há 3 h", "há 2 d"
fn quando(seg) {
    let d = now() - seg;
    if d < 60 {
        "agora"
    } else if d < 3600 {
        `há ${d / 60} min`
    } else if d < 86400 {
        `há ${d / 3600} h`
    } else {
        `há ${d / 86400} d`
    }
}

fn busca_ip() {
    if !setting("ip") {
        return;
    }
    if !http_get_async("https://api.ipify.org?format=json", "chegou_ip") {
        ui("ip", "ocupado");
    }
}

fn chegou_ip(r) {
    if r.ok {
        ui("ip", parse_json(r.body).ip);
    } else if r.err != "" {
        ui("ip", "sem rede");
    } else {
        ui("ip", `erro ${r.status}`);
    }
}
