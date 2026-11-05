// =====================================================
//  Carcasa de UPS Interactiva
//  Ejes: X = ancho, Y = profundidad (frente en Y = 0), Z = alto
//  Unidades: milímetros
// =====================================================

// ================= VARIABLES GLOBALES =================

// --- 1. Dimensiones generales ---
ancho_x        = 99;
prof_y         = 288;
alto_z         = 280;
radio_esquinas = 6;     // bordes verticales
radio_hz       = 15;    // bordes horizontales superior/inferior
abombado       = 4;     // flecha de la curvatura convexa del frente

// --- 2. Línea de ensamble ---
bisel_z        = 200;
bisel_alto     = 1.5;
bisel_prof     = 2;
bisel_lateral  = 20;    // cuánto se extiende hacia los costados (en Y)

// --- 3. Interfaz de usuario ---
lcd_ancho      = 60;
lcd_alto       = 40;
lcd_prof       = 1.5;
lcd_z0         = 220;   // borde inferior de la pantalla (220 → 260)

boton_d        = 8;
boton_salida   = 1;     // cuánto sobresalen de la superficie
boton_paso     = 15;
boton_z        = 210;
n_botones      = 3;

// --- 4. Hendidura central ---
pildora_ancho  = 32;
pildora_z0     = 30;
pildora_z1     = 180;
pildora_prof   = 5;

// --- 5. Rejillas laterales ---
rej_y0         = 50;
rej_y1         = 250;
rej_z0         = 20;
rej_z1         = 260;
rej_cols       = 6;
rej_filas      = 12;
ranura_ancho   = 2;     // en Y
ranura_alto    = 12;    // en Z
ranura_prof    = 15;    // en X (hacia adentro)
ranura_angulo  = 30;    // inclinación (exterior más bajo que interior)

// --- Calidad / tolerancias ---
eps = 0.1;
$fn = 64;

// --- Derivados ---
// Radio del arco frontal para lograr la flecha "abombado" sobre todo el ancho
R_frente = (pow(ancho_x / 2, 2) + pow(abombado, 2)) / (2 * abombado);
cx       = ancho_x / 2;


// ================= 1. CUERPO PRINCIPAL =================

// Planta X-Y: rectángulo con frente convexo y 4 bordes verticales redondeados
module planta_xy() {
    offset(r = radio_esquinas) offset(delta = -radio_esquinas)
        intersection() {
            square([ancho_x, prof_y]);
            translate([cx, R_frente]) circle(r = R_frente, $fn = 720);
        }
}

// Perfil Y-Z: bordes horizontales superior e inferior fuertemente redondeados
module perfil_yz() {
    offset(r = radio_hz) offset(delta = -radio_hz)
        square([prof_y, alto_z]);
}

module cuerpo() {
    intersection() {
        // Bordes verticales + frente abombado
        linear_extrude(height = alto_z) planta_xy();
        // Bordes horizontales (perfil extruido a lo largo de X)
        rotate([90, 0, 90]) linear_extrude(height = ancho_x) perfil_yz();
    }
}

// Cáscara de espesor "p" bajo la superficie exterior (sigue la curva del frente).
// Se usa para tallar rebajes de profundidad constante sobre la cara curva.
module cascara(p, z0 = -eps, h = alto_z + 2 * eps) {
    translate([0, 0, z0])
        linear_extrude(height = h)
            difference() {
                offset(delta = 1) planta_xy();          // sobresale del exterior (+margen)
                offset(delta = -p) planta_xy();         // límite de profundidad
            }
}

// Posición Y de la superficie frontal en una coordenada X dada
function y_frente(x) = R_frente - sqrt(pow(R_frente, 2) - pow(x - cx, 2));


// ================= 2. LÍNEA DE ENSAMBLE =================
module corte_bisel() {
    intersection() {
        cascara(bisel_prof, bisel_z - bisel_alto / 2, bisel_alto);
        // Limita el corte al frente y a los primeros mm de los costados
        translate([-1 - eps, -1 - eps, bisel_z - bisel_alto])
            cube([ancho_x + 2 + 2 * eps, bisel_lateral + abombado, bisel_alto * 2]);
    }
}


// ================= 3. INTERFAZ DE USUARIO =================

// Cavidad de la pantalla LCD (resta)
module corte_lcd() {
    intersection() {
        cascara(lcd_prof);
        translate([cx - lcd_ancho / 2, -1 - eps, lcd_z0])
            cube([lcd_ancho, abombado + 2, lcd_alto]);
    }
}

// Botonera (suma): cilindros acostados que sobresalen boton_salida
module botones() {
    color("#d0d0d0")
    for (i = [0 : n_botones - 1]) {
        bx = cx + (i - (n_botones - 1) / 2) * boton_paso;
        translate([bx, y_frente(bx) - boton_salida, boton_z])
            rotate([-90, 0, 0])
                cylinder(d = boton_d, h = boton_salida + 2);   // 2 mm empotrados
    }
}


// ================= 4. HENDIDURA CENTRAL =================
module corte_pildora() {
    sep = (pildora_z1 - pildora_z0) - pildora_ancho;   // 118 mm entre centros
    intersection() {
        cascara(pildora_prof);
        // Píldora vertical: hull entre dos cilindros acostados
        hull()
            for (z = [pildora_z0 + pildora_ancho / 2, pildora_z0 + pildora_ancho / 2 + sep])
                translate([cx, -1 - eps, z]) rotate([-90, 0, 0])
                    cylinder(d = pildora_ancho, h = abombado + pildora_prof + 2);
    }
}


// ================= 5. REJILLAS LATERALES =================

// Una ranura sobre el costado X = 0, inclinada: entra subiendo hacia el interior
module ranura() {
    rotate([0, -ranura_angulo, 0])
        translate([-3, -ranura_ancho / 2, -ranura_alto / 2])
            cube([ranura_prof + 3, ranura_ancho, ranura_alto]);   // +3 asegura salida al exterior
}

module matriz_ranuras() {
    paso_y = (rej_y1 - rej_y0) / (rej_cols - 1);
    paso_z = (rej_z1 - rej_z0 - ranura_alto) / (rej_filas - 1);
    for (c = [0 : rej_cols - 1], f = [0 : rej_filas - 1])
        translate([0, rej_y0 + c * paso_y, rej_z0 + ranura_alto / 2 + f * paso_z])
            ranura();
}

module cortes_rejillas() {
    matriz_ranuras();                                       // lado X = 0
    translate([ancho_x, 0, 0]) mirror([1, 0, 0]) matriz_ranuras();   // lado X = ancho_x
}


// ================= ENSAMBLE =================
module ups() {
    union() {
        color("#1e1e20")
        difference() {
            cuerpo();
            corte_bisel();      // 2. línea de ensamble
            corte_lcd();        // 3. cavidad LCD
            corte_pildora();    // 4. hendidura central
            cortes_rejillas();  // 5. rejillas laterales
        }
        // Fondo de la pantalla (vidrio) dentro de la cavidad
        color("#4a6a80")
        translate([0, 0, lcd_z0 + 2])
            linear_extrude(height = lcd_alto - 4)
                intersection() {
                    // lámina de 0.3 mm apoyada en el fondo de la cavidad
                    difference() {
                        offset(delta = -(lcd_prof - 0.3)) planta_xy();
                        offset(delta = -(lcd_prof + eps)) planta_xy();
                    }
                    translate([cx - lcd_ancho / 2 + 2, -1]) square([lcd_ancho - 4, abombado + 2]);
                }
        botones();              // 3. botonera
    }
}

ups();
