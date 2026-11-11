// Lógica do plugin "Pulso". Roda isolado, só com a API do MiniUtils:
// - on_event: as leituras do provedor "sys" (uses no manifesto);
// - store_get/store_set: o recorde, guardado entre execuções;
// - run_async: o processo culpado num pico, sem travar o script;
// - http_get_async + parse_json: o IP público (só api.ipify.org, de [permissions] net);
// - fact: conta à conversa entre mascotes quem causou o pico.

fn start() {
    this.cpu = [];
    this.alto = false;
    this.ultimo_ps = 0;
    this.batida = false;
    this.temp_aviso = false;
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
        ui("ip", "consultando…");
        this.busca_ip();
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
    if topic != "sys" {
        return;
    }
    let cpu = data.cpu;
    let temp = data.cpu_temp;

    // gráfico: as últimas 30 leituras
    this.cpu.push(cpu);
    if this.cpu.len() > 30 {
        this.cpu.remove(0);
    }
    this.batida = !this.batida;
    ui("historico", this.cpu);
    ui("batida", this.batida);
    ui("cpu", `${cpu.round().to_int()}%`);

    let ram = if data.mem_total > 0 { data.mem_used * 100 / data.mem_total } else { 0 };
    let detalhe = `RAM ${ram}%`;
    if temp > 0.0 {
        detalhe += ` · ${temp.round().to_int()} °C`;
    }
    ui("detalhe", detalhe);
    summary(`CPU ${cpu.round().to_int()}% · ${detalhe}`);

    this.guarda_recorde(cpu, temp);

    // pico: acha o culpado (no máximo a cada 30 s) e sai do pico só 10 pontos abaixo
    if cpu >= this.limite {
        if !this.alto {
            this.alto = true;
        }
        if now() - this.ultimo_ps >= 30 {
            this.ultimo_ps = now();
            run_async(["ps", "-eo", "comm,pcpu", "--sort=-pcpu", "--no-headers"], "achou_culpado");
        }
    } else if this.alto && cpu < this.limite - 10.0 {
        this.alto = false;
        ui("culpado", "");
    }

    // temperatura crítica: alarme e um aviso só (até esfriar)
    let quente = temp >= 90.0;
    if quente && !this.temp_aviso {
        notify("Pulso", `CPU a ${temp.round().to_int()} °C`);
    }
    this.temp_aviso = quente;

    mood(if quente { "alarm" } else if this.alto { "busy" } else if cpu >= 30.0 { "happy" } else { "idle" });
}

fn achou_culpado(r) {
    if !r.ok {
        return;
    }
    let linha = r.out.split("\n")[0];
    let partes = linha.split();
    if partes.len() < 2 {
        return;
    }
    let nome = partes[0];
    let pct = parse_float(partes[partes.len() - 1]);
    ui("culpado", `${nome} (${pct.round().to_int()}%)`);
    // a mascote conta à conversa quem foi (o host já conta a mudança de humor)
    if this.alto {
        fact("strain", nome, pct);
    }
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
    let texto = `CPU ${rec.cpu.round().to_int()}% ${quando(rec.cpu_em)}`;
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
        ui("ip", "ocupado, tente de novo");
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
