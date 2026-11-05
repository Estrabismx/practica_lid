// =====================================================
//  Carcasa de Router Gigabit (estilo TP-Link Archer C6)
//  Ejes: X = ancho, Y = profundidad (frente en Y = 0, antenas en Y ≈ 117),
//        Z = alto
//  Unidades: milímetros
// =====================================================

// ================= VARIABLES GLOBALES =================

// --- 1. Dimensiones generales ---
ancho_x        = 215;
prof_y         = 117;
alto_chasis_z  = 32;
alto_antenas   = 160;
radio_esquinas = 4;

// --- 2. Superficie superior facetada ---
ang_lateral    = 3;      // caída hacia izquierda y derecha (grados)
ang_frontal    = 4;      // caída hacia el frente (grados)
y_cumbrera     = 75;     // línea desde donde la cara superior cae hacia el frente

// --- 3. Textura (estrías) ---
estria_ancho   = 0.5;
estria_prof    = 0.5;
paso_long      = 4;      // separación de estrías longitudinales (paralelas a X)
paso_trans     = 6;      // separación de estrías transversales (paralelas a Y)
margen_textura = 8;      // borde liso alrededor de la textura

// --- 4. Panel frontal y LEDs ---
bisel_alto     = 16;     // altura del bisel frontal inferior
bisel_prof     = 8;      // cuánto se mete hacia adentro en la base
n_leds         = 5;      // Encendido, 2.4GHz, 5GHz, LAN, Internet
led_r          = 1;
led_paso       = 8;
led_prof       = 2;

// --- 5. Antenas ---
antena_x       = [20, 78, 136, 195];   // centros en X
antena_base    = 12;     // sección 12 × 12
antena_radio   = 1.5;    // redondeo de aristas
antena_z0      = 6;      // altura de la bisagra
antena_sep     = 1;      // separación respecto de la cara trasera

// --- Calidad / tolerancias ---
eps = 0.1;
$fn = 32;

cx = ancho_x / 2;


// ================= 1. CHASIS BASE =================
// Hull de 4 cilindros en las esquinas del plano X-Y
module chasis_base() {
    hull()
        for (x = [radio_esquinas, ancho_x - radio_esquinas],
             y = [radio_esquinas, prof_y - radio_esquinas])
            translate([x, y, 0]) cylinder(r = radio_esquinas, h = alto_chasis_z);
}


// ================= 2. CORTES DE LA SUPERFICIE FACETADA =================
// Planos inclinados que rebajan los bordes izquierdo, derecho y frontal.
// Al cruzarse forman el patrón en "X" con el centro más alto.
module corte_lateral_izq() {
    translate([cx, -eps - 1, alto_chasis_z])
        rotate([0, -ang_lateral, 0])
            translate([-ancho_x, 0, 0])
                cube([ancho_x, prof_y + 2 + 2 * eps, 50]);
}

module corte_lateral_der() {
    translate([ancho_x, 0, 0]) mirror([1, 0, 0]) corte_lateral_izq();
}

module corte_frontal() {
    translate([-eps - 1, y_cumbrera, alto_chasis_z])
        rotate([ang_frontal, 0, 0])
            translate([0, -prof_y, 0])
                cube([ancho_x + 2 + 2 * eps, prof_y, 50]);
}


// ================= 4a. BISEL FRONTAL INFERIOR =================
// Cuña que mete hacia adentro la parte baja del frente
module corte_bisel() {
    translate([-eps - 1, 0, 0])
        rotate([90, 0, 90])
            linear_extrude(height = ancho_x + 2 + 2 * eps)
                polygon([[-eps - 1, -eps - 1],
                         [bisel_prof, -eps - 1],
                         [bisel_prof, 0],
                         // prolonga la misma pendiente fuera del cuerpo
                         [-eps - 1, bisel_alto + (eps + 1) * bisel_alto / bisel_prof]]);
}

// Cuerpo con la forma exterior final (sin textura ni LEDs)
module cuerpo() {
    difference() {
        chasis_base();
        corte_lateral_izq();   // 2. faceta izquierda
        corte_lateral_der();   // 2. faceta derecha
        corte_frontal();       // 2. faceta frontal
        corte_bisel();         // 4. bisel inferior frontal
    }
}


// ================= 3. TEXTURA DE ESTRÍAS =================
// Capa de espesor "estria_prof" que sigue la superficie superior facetada
// (se desplaza +eps hacia arriba para no dejar caras coincidentes).
module capa_superior() {
    difference() {
        translate([0, 0, eps]) cuerpo();
        translate([0, 0, -estria_prof]) cuerpo();
    }
}

module rejilla_estrias() {
    x0 = margen_textura;  x1 = ancho_x - margen_textura;
    y0 = margen_textura + bisel_prof;  y1 = prof_y - margen_textura;
    // Longitudinales (paralelas a X)
    for (y = [y0 : paso_long : y1])
        translate([x0, y - estria_ancho / 2, 0])
            cube([x1 - x0, estria_ancho, alto_chasis_z + 1]);
    // Transversales (paralelas a Y)
    for (x = [x0 : paso_trans : x1])
        translate([x - estria_ancho / 2, y0, 0])
            cube([estria_ancho, y1 - y0, alto_chasis_z + 1]);
}

module corte_textura() {
    intersection() {
        capa_superior();
        rejilla_estrias();
    }
}


// ================= 4b. LEDs DE ESTADO =================
// Huecos perpendiculares a la cara inclinada del bisel
ang_bisel = atan2(bisel_alto, bisel_prof);   // inclinación de la cara

module corte_leds() {
    for (i = [0 : n_leds - 1]) {
        lx = cx + (i - (n_leds - 1) / 2) * led_paso;
        // Punto medio de la cara inclinada
        translate([lx, bisel_prof / 2, bisel_alto / 2])
            rotate([-ang_bisel, 0, 0])   // eje del hueco = normal de la cara, hacia adentro
                translate([0, 0, -1])    // empieza 1 mm fuera de la cara (evita caras coincidentes)
                    cylinder(r = led_r, h = led_prof + 1);
    }
}


// ================= 5. ANTENAS =================
// Prisma de 12 × 12 × 160 con aristas redondeadas (hull de 8 esferas)
module antena() {
    a = antena_base / 2 - antena_radio;
    color("#151517")
    hull()
        for (x = [-a, a], y = [-a, a], z = [antena_radio, alto_antenas - antena_radio])
            translate([x, y, z]) sphere(r = antena_radio, $fn = 16);
}

// Bisagra que une cada antena con la cara trasera
module bisagra() {
    color("#151517")
        translate([-antena_base / 2 + 2, -eps - 1, 0])
            cube([antena_base - 4, antena_sep + 2 + eps, 14]);
}

module antenas() {
    for (x = antena_x)
        translate([x, prof_y + antena_sep + antena_base / 2, antena_z0]) {
            antena();
            translate([0, -antena_base / 2 - antena_sep, 2]) bisagra();
        }
}


// ================= ENSAMBLE =================
module router() {
    color("#2a2a2d")
    difference() {
        cuerpo();
        corte_textura();   // 3. estrías superiores
        corte_leds();      // 4. LEDs de estado
    }
    antenas();             // 5. antenas traseras
}

router();
