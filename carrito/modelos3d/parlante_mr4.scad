// =====================================================
//  Monitor de estudio Edifier MR4 — altavoz activo, negro
//  Ejes: X = ancho, Y = profundidad (frente en Y = 0, trasera en Y = prof_y),
//        Z = alto (apoyo en Z = 0)
//  Unidades: milímetros
// =====================================================

// ================= VARIABLES GLOBALES =================

// --- 1. Gabinete MDF ---
ancho_x        = 140;
prof_y         = 198;
alto_z         = 228;
radio_esquinas = 2;      // 0 = aristas vivas (sin minkowski)

// --- 2. Woofer 4" ---
woofer_z        = 95;
woofer_r        = 51;    // rebaje visible (Ø 102)
woofer_prof     = 8;     // profundidad del rebaje
cono_r_ext      = 46;    // borde exterior del diafragma
cono_r_int      = 17;    // fondo del cono (junto a la tapa)
cono_prof       = 4.5;   // profundidad del cono
suspension_r    = 2.5;   // radio de la goma (surround)
tapa_r          = 16;    // tapa antipolvo
tapa_alto       = 2.5;

// --- 3. Tweeter 1" ---
tweeter_z       = 185;
tweeter_marco_r = 20;    // rebaje Ø 40
tweeter_prof    = 3;
cupula_r        = 12.5;  // Ø 25
cupula_salida   = 2;     // cuánto sobresale de la cara frontal

// --- 4. Controles frontales ---
perilla_x       = 115;
perilla_z       = 20;
perilla_d       = 12;
perilla_alto    = 10;
jack_x          = [25, 45];   // AUX y auriculares
jack_z          = 20;
jack_d          = 4;
jack_prof       = 5;

// --- 5. Bass reflex trasero ---
reflex_z        = 160;
reflex_d        = 35;
reflex_largo    = 80;    // largo del tubo de sintonía
reflex_chaflan  = 4;     // abocinado de la boca

// --- Calidad / tolerancias ---
eps = 0.1;
$fn = 96;

cx = ancho_x / 2;

// Utilidad: cilindro cuyo eje apunta hacia +Y (hacia el interior desde el frente)
module cil_y(r = 1, h = 1, r1 = undef, r2 = undef) {
    rotate([-90, 0, 0])
        if (r1 == undef) cylinder(r = r, h = h);
        else cylinder(r1 = r1, r2 = r2, h = h);
}


// ================= 1. modulo_gabinete() =================
module modulo_gabinete() {
    if (radio_esquinas > 0)
        translate([radio_esquinas, radio_esquinas, radio_esquinas])
            minkowski() {
                cube([ancho_x - 2 * radio_esquinas,
                      prof_y  - 2 * radio_esquinas,
                      alto_z  - 2 * radio_esquinas]);
                sphere(r = radio_esquinas, $fn = 16);
            }
    else
        cube([ancho_x, prof_y, alto_z]);
}


// ================= 2. modulo_woofer() =================
// 2a. Rebaje cilíndrico en el panel frontal (se resta)
module corte_woofer() {
    translate([cx, -eps, woofer_z])
        cil_y(r = woofer_r, h = woofer_prof + eps);
}

// 2b. Diafragma, suspensión y tapa antipolvo (se suman dentro del rebaje)
module modulo_woofer() {
    y_fondo  = woofer_prof;               // fondo del rebaje
    y_borde  = woofer_prof - cono_prof;   // borde exterior del cono (más adelante)
    translate([cx, 0, woofer_z]) {
        // Diafragma: cono truncado hacia adentro (polipropileno con mica)
        color("#3a3a3c")
        difference() {
            translate([0, y_borde, 0])
                cil_y(r = cono_r_ext, h = cono_prof + eps);
            // superficie cónica: r menor en el fondo, r mayor hacia el frente
            translate([0, y_borde - eps, 0])
                cil_y(r1 = cono_r_ext - 0.5, r2 = cono_r_int, h = cono_prof - 0.5);
        }
        // Suspensión de goma (toroide)
        color("#151515")
        translate([0, y_borde, 0]) rotate([-90, 0, 0])
            rotate_extrude($fn = 96)
                translate([cono_r_ext + suspension_r - 0.5, 0]) circle(r = suspension_r, $fn = 24);
        // Anillo de fijación (cierra el hueco entre suspensión y pared del rebaje)
        color("#151515")
        difference() {
            translate([0, y_borde, 0]) cil_y(r = woofer_r + eps, h = cono_prof + eps);
            translate([0, y_borde - eps, 0]) cil_y(r = cono_r_ext + 2 * suspension_r - 1, h = cono_prof + 3 * eps);
        }
        // Tapa antipolvo central
        color("#202022")
        translate([0, y_fondo - 0.5 - tapa_alto, 0])
            cil_y(r = tapa_r, h = tapa_alto + 0.5);
    }
}


// ================= 3. modulo_tweeter() =================
// 3a. Marco rebajado (se resta)
module corte_tweeter() {
    translate([cx, -eps, tweeter_z])
        cil_y(r = tweeter_marco_r, h = tweeter_prof + eps);
}

// 3b. Cúpula de seda: media esfera (achatada) que sobresale ligeramente
module modulo_tweeter() {
    alto_cupula = tweeter_prof + cupula_salida;
    color("#2a2a2c")
    translate([cx, tweeter_prof + eps, tweeter_z])
        scale([1, alto_cupula / cupula_r, 1])
            intersection() {
                sphere(r = cupula_r);
                // solo la mitad que mira hacia el frente (-Y)
                translate([-cupula_r, -cupula_r, -cupula_r])
                    cube([2 * cupula_r, cupula_r, 2 * cupula_r]);
            }
    // Anillo del marco (borde metálico)
    color("#555")
    translate([cx, tweeter_prof - 0.5, tweeter_z])
        difference() {
            cil_y(r = cupula_r + 3, h = 0.5 + eps);
            translate([0, -eps, 0]) cil_y(r = cupula_r + 0.5, h = 0.5 + 3 * eps);
        }
}


// ================= 4. modulo_controles_frontales() =================
// 4a. Entradas jack 3.5 mm (se restan)
module corte_jacks() {
    for (x = jack_x)
        translate([x, -eps, jack_z])
            cil_y(r = jack_d / 2, h = jack_prof + eps);
}

// 4b. Perilla de volumen / encendido (se suma, sobresale hacia -Y)
module modulo_controles_frontales() {
    color("#bbbbbb")
    translate([perilla_x, 1, perilla_z])   // 1 mm empotrada en el gabinete
        rotate([90, 0, 0])
            difference() {
                cylinder(d = perilla_d, h = perilla_alto + 1);
                // marca indicadora en la cara frontal
                translate([-0.5, perilla_d / 4, perilla_alto + 1 - 0.5])
                    cube([1, perilla_d / 4, 0.5 + eps]);
            }
}


// ================= 5. modulo_bass_reflex() =================
module corte_bass_reflex() {
    translate([cx, prof_y + eps, reflex_z])
        rotate([90, 0, 0]) {
            // Tubo de sintonía
            cylinder(d = reflex_d, h = reflex_largo + eps);
            // Boca abocinada
            cylinder(d1 = reflex_d + 2 * reflex_chaflan, d2 = reflex_d, h = reflex_chaflan + eps);
        }
}


// ================= ENSAMBLE =================
module edifier_mr4() {
    union() {
        color("#141414")
        difference() {
            modulo_gabinete();        // 1
            corte_woofer();           // 2a
            corte_tweeter();          // 3a
            corte_jacks();            // 4a
            corte_bass_reflex();      // 5
        }
        modulo_woofer();              // 2b
        modulo_tweeter();             // 3b
        modulo_controles_frontales(); // 4b
    }
}

edifier_mr4();
