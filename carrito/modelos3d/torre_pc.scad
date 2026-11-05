// =====================================================
//  Torre de computador (gabinete ATX tipo mid-tower)
//  Dimensiones exteriores totales:
//    Alto  (Z): 498   mm
//    Ancho (X): 210   mm
//    Largo (Y): 411.6 mm   (frente en Y = 0)
//  Unidades: milímetros
// =====================================================

$fn = 48;

// ---------- Parámetros principales ----------
ALTO  = 498;
ANCHO = 210;
LARGO = 411.6;

alto_patas   = 12;    // altura de las patas
radio_borde  = 6;     // redondeo de aristas del chasis
esp_frontal  = 18;    // espesor del panel frontal
esp_pared    = 2;     // grosor visual de paneles

alto_cuerpo  = ALTO - alto_patas;        // 486
largo_chasis = LARGO - esp_frontal;      // 393.6

// ---------- Utilidades ----------
module caja_redondeada(size, r) {
    // Caja con aristas redondeadas en las 4 aristas verticales (eje Y)
    hull() {
        for (x = [r, size[0] - r], z = [r, size[2] - r])
            translate([x, 0, z]) rotate([-90, 0, 0])
                cylinder(r = r, h = size[1]);
    }
}

module rejilla_circular(d, barras = 6, ancho_barra = 3, prof = 3) {
    // Agujeros concéntricos tipo rejilla de ventilador
    difference() {
        cylinder(d = d, h = prof);
        for (i = [1 : barras])
            translate([0, 0, -1])
                difference() {
                    cylinder(d = d * i / barras, h = prof + 2);
                    cylinder(d = d * i / barras - ancho_barra * 2, h = prof + 2);
                }
    }
}

module ranuras(n, largo, ancho, paso, prof) {
    for (i = [0 : n - 1])
        translate([i * paso, 0, 0]) cube([ancho, largo, prof]);
}

// ---------- Chasis ----------
module chasis() {
    color("#2b2b2e")
    difference() {
        translate([0, esp_frontal, alto_patas])
            caja_redondeada([ANCHO, largo_chasis, alto_cuerpo], radio_borde);

        // Ranuras de ventilación superiores
        translate([40, esp_frontal + 60, ALTO - 2])
            for (i = [0 : 11])
                translate([0, i * 22, 0]) cube([130, 8, 5]);

        // Hueco ventana lateral (lado izquierdo, X = 0)
        translate([-1, esp_frontal + 40, alto_patas + 120])
            cube([esp_pared + 1, 300, 330]);

        // --- Panel trasero (Y = LARGO) ---
        // Hueco I/O de placa madre
        translate([25, LARGO - esp_pared - 1, ALTO - 210])
            cube([45, esp_pared + 2, 160]);
        // Hueco ventilador trasero 120 mm
        translate([140, LARGO - esp_pared - 1, ALTO - 120])
            rotate([-90, 0, 0]) cylinder(d = 116, h = esp_pared + 2);
        // Ranuras de expansión (PCI)
        for (i = [0 : 6])
            translate([25 + i * 20, LARGO - esp_pared - 1, alto_patas + 120])
                cube([14, esp_pared + 2, 110]);
        // Hueco fuente de poder (abajo)
        translate([30, LARGO - esp_pared - 1, alto_patas + 15])
            cube([150, esp_pared + 2, 86]);
    }
}

// ---------- Vidrio lateral ----------
module vidrio_lateral() {
    color("#88aacc", 0.35)
        translate([0.5, esp_frontal + 40, alto_patas + 120])
            cube([1.5, 300, 330]);
}

// ---------- Panel frontal ----------
module panel_frontal() {
    // Marco frontal
    color("#1a1a1c")
    difference() {
        // Se retrasa 1.2 mm para que botones y puertos no excedan el largo total.
        // Se prolonga 1 mm dentro del chasis para que ambos se fusionen sin
        // caras coincidentes (evita aristas no-manifold al exportar a STEP).
        translate([0, 1.2, alto_patas])
            caja_redondeada([ANCHO, esp_frontal - 1.2 + 1, alto_cuerpo], radio_borde);
        // Malla frontal (rebaje)
        translate([20, -1, alto_patas + 40])
            cube([ANCHO - 40, 4, alto_cuerpo - 110]);
    }

    // Malla frontal con perforaciones
    color("#3a3a3e")
    difference() {
        translate([20, 2, alto_patas + 40])
            cube([ANCHO - 40, 1.5, alto_cuerpo - 110]);
        for (x = [30 : 10 : ANCHO - 30], z = [alto_patas + 50 : 10 : ALTO - 80])
            translate([x, 0, z]) rotate([-90, 0, 0]) cylinder(d = 6, h = 6, $fn = 6);
    }

    // Ventiladores frontales (3 x 120 mm) visibles tras la malla
    for (i = [0 : 2])
        translate([ANCHO / 2, 6, alto_patas + 100 + i * 125])
            rotate([-90, 0, 0])
                ventilador_120();

    // Panel de botones / puertos (parte superior frontal)
    translate([0, 1.2, ALTO - 60]) {
        // Botón de encendido
        color("#c0c0c0")
            translate([ANCHO / 2, -1, 30]) rotate([-90, 0, 0]) cylinder(d = 16, h = 3);
        color("#00aaff")
            translate([ANCHO / 2, -1.2, 30]) rotate([-90, 0, 0])
                difference() { cylinder(d = 18, h = 0.5); cylinder(d = 16.5, h = 1); }
        // Botón de reinicio
        color("#c0c0c0")
            translate([ANCHO / 2 + 22, -0.5, 30]) rotate([-90, 0, 0]) cylinder(d = 6, h = 2);
        // Puertos USB-A
        color("#0a0a0a")
            for (i = [0 : 1])
                translate([35 + i * 22, -0.5, 26]) cube([13, 2, 5]);
        // Puerto USB-C
        color("#0a0a0a")
            translate([140, -0.5, 26]) cube([9, 2, 3.5]);
        // Jack de audio
        color("#0a0a0a")
            for (i = [0 : 1])
                translate([160 + i * 12, -0.5, 28.5]) rotate([-90, 0, 0]) cylinder(d = 4, h = 2);
    }
}

module ventilador_120() {
    // Marco
    color("#202020")
    difference() {
        translate([-60, -60, 0]) cube([120, 120, 10]);
        translate([0, 0, -1]) cylinder(d = 114, h = 12);
    }
    // Aspas
    color("#404048")
    for (a = [0 : 360 / 7 : 359])
        rotate([0, 0, a]) translate([0, 0, 2])
            rotate([20, 0, 0]) translate([0, -8, 0]) cube([54, 16, 1.5]);
    // Buje
    color("#303030") cylinder(d = 40, h = 10);
}

// ---------- Fuente de poder (vista trasera) ----------
module fuente_poder() {
    translate([30, LARGO - 4, alto_patas + 15]) {
        color("#202022") cube([150, 3, 86]);
        // Rejilla del ventilador de la fuente
        color("#555")
            translate([105, 3, 43]) rotate([-90, 0, 0])
                rejilla_circular(70, 5, 1.5, 1);
        // Conector de poder e interruptor
        color("#111")
            translate([15, 2, 30]) cube([28, 2, 22]);
        color("#aa0000")
            translate([50, 2, 33]) cube([10, 2, 16]);
    }
}

// ---------- Rejilla ventilador trasero ----------
module rejilla_trasera() {
    color("#444")
        translate([140, LARGO - 1, ALTO - 120]) rotate([-90, 0, 0])
            rejilla_circular(116, 6, 1.5, 1);
}

// ---------- I/O trasero ----------
module io_trasero() {
    color("#9a9a9a")
        translate([25, LARGO - 1.5, ALTO - 210]) cube([45, 1, 160]);
    color("#111")
    for (i = [0 : 7])
        translate([33, LARGO - 2, ALTO - 200 + i * 18]) cube([28, 1, 8]);
}

// ---------- Tapas de ranuras PCI ----------
module tapas_pci() {
    color("#777")
    for (i = [0 : 6])
        translate([25 + i * 20, LARGO - 1, alto_patas + 120])
            cube([14, 1, 110]);
}

// ---------- Patas ----------
module patas() {
    color("#111")
    for (x = [25, ANCHO - 25], y = [35, LARGO - 35])
        translate([x, y, 0]) cylinder(d1 = 30, d2 = 36, h = alto_patas);
}

// ---------- Ensamble ----------
module torre_pc() {
    chasis();
    vidrio_lateral();
    panel_frontal();
    fuente_poder();
    rejilla_trasera();
    io_trasero();
    tapas_pci();
    patas();
}

torre_pc();
