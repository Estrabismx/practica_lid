// =====================================================
//  Base de seguridad para notebook (con brazos laterales)
//  Cuerpo: 297 × 113 × 28 mm (ancho × profundidad × alto)
//  Ancho total con brazos abiertos (15,6"): ~360 mm
//  Huella total con notebook encima: ~360 × 250 mm
//
//  Ejes: X = ancho, Y = profundidad (frente/usuario en Y = 0),
//        Z = alto. La base va bajo la parte trasera del notebook.
//  Unidades: milímetros
// =====================================================

$fn = 32;

// ---------- Parámetros principales ----------
CUERPO_ANCHO = 297;
CUERPO_PROF  = 113;
CUERPO_ALTO  = 28;
radio_borde  = 5;

ancho_abierto = 360;   // ancho total con brazos (≈ 360 para 15,6")
huella_prof   = 250;   // profundidad del notebook de 15,6"

// Brazos (medidas aproximadas: la ficha no las especifica)
brazo_prof     = 40;   // ancho del brazo en Y
brazo_esp      = 3;    // espesor de la placa
brazo_z        = CUERPO_ALTO - 8;   // altura donde sale la placa
pestana_esp    = 3;    // espesor de la pestaña vertical
pestana_alto   = 22;   // sobre la cara superior del cuerpo
goma_esp       = 2;    // tope de goma

mostrar_candado  = false;  // la ficha permite omitirlo

// ---------- Derivados ----------
x0        = (ancho_abierto - CUERPO_ANCHO) / 2;   // inicio del cuerpo en X
y0        = huella_prof - CUERPO_PROF;            // cuerpo pegado al borde trasero

// ---------- Utilidades ----------
module caja_redondeada(size, r) {
    hull()
        for (x = [r, size[0] - r], y = [r, size[1] - r], z = [r, size[2] - r])
            translate([x, y, z]) sphere(r = r);
}

// ---------- Cuerpo ----------
module cuerpo() {
    color("#b8bcc2")
    difference() {
        translate([x0, y0, 0])
            caja_redondeada([CUERPO_ANCHO, CUERPO_PROF, CUERPO_ALTO], radio_borde);

        // Guías donde se deslizan los brazos
        for (lado = [0, 1])
            translate([lado == 0 ? x0 - 1 : x0 + CUERPO_ANCHO - 60,
                       y0 + (CUERPO_PROF - brazo_prof) / 2 - 0.5,
                       brazo_z - 0.5])
                cube([61, brazo_prof + 1, brazo_esp + 1]);

        // Ranura de seguridad (cara trasera, extremo derecho)
        translate([x0 + CUERPO_ANCHO - 30, y0 + CUERPO_PROF - 4, CUERPO_ALTO / 2 - 1.5])
            cube([7, 5, 3]);
    }
    // Patas de goma
    color("#222")
    for (x = [x0 + 20, x0 + CUERPO_ANCHO - 20], y = [y0 + 15, y0 + CUERPO_PROF - 15])
        translate([x, y, 0]) cylinder(d = 14, h = 1);
}

// ---------- Brazo lateral ----------
// Se modela el brazo izquierdo y se refleja para el derecho.
module brazo() {
    yb = y0 + (CUERPO_PROF - brazo_prof) / 2;
    largo = x0 + 55;   // tramo dentro de la guía + tramo exterior
    // Placa
    color("#9a9ea4")
        translate([0, yb, brazo_z]) cube([largo, brazo_prof, brazo_esp]);
    // Pestaña vertical
    color("#9a9ea4")
        translate([0, yb, brazo_z])
            cube([pestana_esp, brazo_prof, CUERPO_ALTO - brazo_z + pestana_alto]);
    // Tope de goma (cara interior)
    color("#111")
        translate([pestana_esp, yb + 4, CUERPO_ALTO + 2])
            cube([goma_esp, brazo_prof - 8, pestana_alto - 4]);
}

module brazos() {
    brazo();
    translate([ancho_abierto, 0, 0]) mirror([1, 0, 0]) brazo();
}

// ---------- Candado (opcional) ----------
module candado() {
    xs = x0 + CUERPO_ANCHO - 26.5;
    ys = y0 + CUERPO_PROF;
    color("#555") {
        translate([xs - 10, ys, CUERPO_ALTO / 2 - 9]) cube([20, 25, 18]);
        // Cable de acero
        translate([xs, ys + 25, CUERPO_ALTO / 2])
            rotate([-90, 0, 0]) cylinder(d = 5, h = 120);
    }
}

// ---------- Ensamble ----------
module seguro_pc() {
    cuerpo();
    brazos();
    if (mostrar_candado) candado();
}

seguro_pc();
