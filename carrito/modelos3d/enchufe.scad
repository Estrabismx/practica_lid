// =====================================================
//  Regleta de enchufes para rack 19" (1U)
//  Dimensiones exteriores totales:
//    Ancho (X): 482.6 mm  (estándar 19")
//    Alto  (Z): 44.45 mm  (1U)
//    Prof. (Y): 44    mm  (frente en Y = 0)
//  Unidades: milímetros
// =====================================================

$fn = 48;

// ---------- Parámetros principales ----------
ANCHO_TOTAL  = 482.6;   // incluye orejas
ANCHO_CUERPO = 432;
ALTO         = 44.45;   // 1U
PROF         = 44;

esp_oreja    = 2;       // espesor de las orejas de montaje
sep_agujeros = 465;     // distancia entre centros izq-der
largo_ranura = 10;      // largo de la perforación alargada
ancho_ranura = 6.5;
z_agujeros   = [6.35, 6.35 + 31.75];   // posiciones estándar en 1U

n_enchufes   = 8;
d_enchufe    = 35;      // diámetro del rebaje de cada enchufe
prof_rebaje  = 3;

sw_ancho     = 30;      // interruptor basculante
sw_alto      = 22;

mostrar_cable = false;  // true agrega el cable trasero (excede la profundidad de 44 mm)

ancho_oreja  = (ANCHO_TOTAL - ANCHO_CUERPO) / 2;   // 25.3
x_cuerpo     = ancho_oreja;
centro_x     = ANCHO_TOTAL / 2;

// ---------- Utilidades ----------
module ranura(largo, ancho, h) {
    // Perforación alargada (stadium), eje a lo largo de X, extruida en Y
    rotate([-90, 0, 0])
        hull() for (dx = [-(largo - ancho) / 2, (largo - ancho) / 2])
            translate([dx, 0, 0]) cylinder(d = ancho, h = h);
}

// ---------- Cuerpo ----------
module cuerpo() {
    color("#2a2a2c")
    difference() {
        translate([x_cuerpo, 0, 0]) cube([ANCHO_CUERPO, PROF, ALTO]);

        // Rebaje del interruptor
        translate([x_switch() - sw_ancho / 2 - 2, -1, ALTO / 2 - sw_alto / 2 - 2])
            cube([sw_ancho + 4, 3, sw_alto + 4]);

        // Rebajes de los enchufes
        for (i = [0 : n_enchufes - 1])
            translate([x_enchufe(i), -1, ALTO / 2])
                rotate([-90, 0, 0]) cylinder(d = d_enchufe, h = prof_rebaje + 1);
    }
}

// ---------- Orejas de montaje ----------
module orejas() {
    // Centros de las perforaciones: x = centro ± 465/2
    x_izq = centro_x - sep_agujeros / 2;   // 8.8
    x_der = centro_x + sep_agujeros / 2;   // 473.8
    color("#3a3a3e") {
        difference() {
            cube([ancho_oreja + 0.01, esp_oreja, ALTO]);
            for (z = z_agujeros) translate([x_izq, -1, z]) ranura(largo_ranura, ancho_ranura, esp_oreja + 2);
        }
        difference() {
            translate([ANCHO_TOTAL - ancho_oreja - 0.01, 0, 0]) cube([ancho_oreja + 0.01, esp_oreja, ALTO]);
            for (z = z_agujeros) translate([x_der, -1, z]) ranura(largo_ranura, ancho_ranura, esp_oreja + 2);
        }
    }
}

// ---------- Posiciones en la cara frontal ----------
margen      = 12;
zona_sw     = sw_ancho + 2 * margen;                       // espacio del interruptor (izq.)
function x_switch()   = x_cuerpo + zona_sw / 2;
paso_enchufe = (ANCHO_CUERPO - zona_sw - margen) / n_enchufes;
function x_enchufe(i) = x_cuerpo + zona_sw + paso_enchufe * (i + 0.5);

// ---------- Interruptor basculante ----------
module interruptor() {
    translate([x_switch(), 0, ALTO / 2]) {
        // Marco
        color("#111")
        difference() {
            translate([-sw_ancho / 2, 0, -sw_alto / 2]) cube([sw_ancho, 3, sw_alto]);
            translate([-sw_ancho / 2 + 3, -1, -sw_alto / 2 + 3]) cube([sw_ancho - 6, 3, sw_alto - 6]);
        }
        // Tecla basculante inclinada (roja, iluminada)
        color("#cc1111")
            translate([0, 1.5, 0]) rotate([0, 0, 0]) rotate([0, -8, 0])
                translate([-(sw_ancho - 7) / 2, -1.5, -(sw_alto - 7) / 2])
                    cube([sw_ancho - 7, 2, sw_alto - 7]);
    }
}

// ---------- Enchufes (tipo L, tres orificios en línea) ----------
module enchufe() {
    color("#e6e6e6")
    difference() {
        rotate([-90, 0, 0]) cylinder(d = d_enchufe - 3, h = 1);
        for (dx = [-9.5, 0, 9.5])
            translate([dx, -1, 0]) rotate([-90, 0, 0]) cylinder(d = dx == 0 ? 5 : 4.5, h = 3);
    }
}

module enchufes() {
    for (i = [0 : n_enchufes - 1])
        translate([x_enchufe(i), prof_rebaje - 1, ALTO / 2]) enchufe();
}

// ---------- Cable de alimentación (trasero) ----------
module cable() {
    color("#111")
        translate([ANCHO_TOTAL - ancho_oreja - 30, PROF, ALTO / 2])
            rotate([-90, 0, 0]) {
                cylinder(d1 = 14, d2 = 9, h = 15);   // pasacable
                cylinder(d = 8, h = 40);
            }
}

// ---------- Ensamble ----------
module regleta_rack() {
    cuerpo();
    orejas();
    interruptor();
    enchufes();
    if (mostrar_cable) cable();
}

regleta_rack();
