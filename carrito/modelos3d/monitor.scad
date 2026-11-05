// =====================================================
//  Monitor de escritorio 24" (16:9) con pedestal
//  Ejes: X = ancho, Y = profundidad (pantalla mirando hacia -Y,
//        cara frontal en Y = 0), Z = alto (mesa en Z = 0)
//  Unidades: milímetros
// =====================================================

// ================= VARIABLES GLOBALES =================

// --- 1. Panel ---
ancho_x        = 540;
alto_z         = 310;
grosor_y       = 15;
radio_esquinas = 5;

// --- 2. Bisel y pantalla ---
bisel_superior_lateral = 5;
bisel_inferior         = 20;
profundidad_pantalla   = 2;
pantalla_ancho = ancho_x - 2 * bisel_superior_lateral;                  // 530
pantalla_alto  = alto_z - bisel_superior_lateral - bisel_inferior;      // 285

// --- 3. Carcasa trasera ---
ancho_trasero       = 200;
alto_trasero        = 150;
profundidad_extra_y = 35;
radio_trasero       = 10;

// --- 4. Cuello ---
cuello_ancho   = 40;   // X
cuello_prof    = 30;   // Y
cuello_alto    = 120;  // Z (largo del pilar)
cuello_angulo  = 8;    // inclinación hacia atrás (grados, eje X)
cuello_y_sup   = 35;   // Y del centro del extremo superior (dentro de la carcasa)
cuello_inserto = 10;   // cuánto entra el cuello sobre el borde inferior de la carcasa trasera

// --- 5. Base ---
base_ancho  = 220;
base_prof   = 180;
base_grosor = 8;
base_radio  = 12;      // redondeo de esquinas (minkowski)

// --- Calidad / tolerancias ---
eps = 0.1;
$fn = 48;

// ================= DERIVADOS =================
cx = ancho_x / 2;

// Extremos del cuello (el inferior se apoya sobre la base)
cuello_dy = cuello_alto * sin(cuello_angulo);
cuello_dz = cuello_alto * cos(cuello_angulo);
cuello_y_inf = cuello_y_sup - cuello_dy;
cuello_z_inf = base_grosor;
cuello_z_sup = cuello_z_inf + cuello_dz;

// Altura del borde inferior del panel: se calcula para que todo el extremo
// superior del cuello quede al menos "cuello_inserto" mm dentro de la carcasa.
// El fondo de la carcasa trasera sube en declive desde el borde del panel
// (Y = grosor_y) hasta el rectángulo trasero (Y = grosor_y + profundidad_extra_y),
// así que el punto crítico es la arista trasera-superior del cuello.
margen_inf_trasero = (alto_z - alto_trasero) / 2;
y_arista = cuello_y_sup + (cuello_prof / 2) * cos(cuello_angulo);
z_arista = cuello_z_sup - (cuello_prof / 2) * sin(cuello_angulo);
frac     = min(1, (y_arista - grosor_y) / profundidad_extra_y);
panel_z  = z_arista - cuello_inserto - margen_inf_trasero * frac;

// Centro de la base: bajo el centro de gravedad aproximado del conjunto
base_y_centro = (cuello_y_inf + (grosor_y + profundidad_extra_y) / 2) / 2;


// ================= UTILIDADES =================
// Rectángulo redondeado en el plano X-Z, extruido a lo largo de +Y
module rect_xz(ancho, alto, radio, prof) {
    hull()
        for (x = [radio, ancho - radio], z = [radio, alto - radio])
            translate([x, 0, z]) rotate([-90, 0, 0])
                cylinder(r = radio, h = prof);
}


// ================= 1 y 2. modulo_pantalla() =================
module modulo_pantalla() {
    translate([0, 0, panel_z]) {
        difference() {
            // 1. Chasis del panel (hull de 4 cilindros con eje en Y)
            color("#1b1b1d") rect_xz(ancho_x, alto_z, radio_esquinas, grosor_y);

            // 2. Área visible: hundimiento de 2 mm, alineada arriba
            color("#0a0f1a")
            translate([bisel_superior_lateral, -eps, bisel_inferior])
                cube([pantalla_ancho, profundidad_pantalla + eps, pantalla_alto]);

            // 2. Logotipo (rebaje sutil centrado en el bisel inferior)
            color("#888")
            translate([cx - 15, -eps, bisel_inferior / 2 - 2])
                cube([30, 0.3 + eps, 4]);
        }
        // 2. Botones bajo el bisel inferior (lado derecho)
        color("#333")
        for (i = [0 : 4])
            translate([ancho_x - 40 - i * 12, grosor_y / 2, eps])
                rotate([180, 0, 0]) cylinder(d = 5, h = 1.5 + eps);
    }
}


// ================= 3. modulo_carcasa_trasera() =================
// Hull entre la cara posterior del panel y un rectángulo de 200 × 150
// desplazado hacia atrás: genera paredes en declive.
module modulo_carcasa_trasera() {
    color("#1b1b1d")
    translate([0, 0, panel_z])
        hull() {
            // Cara posterior plana del panel (lámina delgada, solapada con el panel)
            translate([0, grosor_y - 1, 0])
                rect_xz(ancho_x, alto_z, radio_esquinas, 1);
            // Rectángulo trasero centrado
            translate([cx - ancho_trasero / 2,
                       grosor_y + profundidad_extra_y - 1,
                       (alto_z - alto_trasero) / 2])
                rect_xz(ancho_trasero, alto_trasero, radio_trasero, 1);
        }
}

// Detalles de la carcasa trasera: patrón VESA 100 × 100 y puertos
module detalles_traseros() {
    yb = grosor_y + profundidad_extra_y;
    zc = panel_z + alto_z / 2;
    // Agujeros VESA 100 × 100 (M4)
    for (dx = [-50, 50], dz = [-50, 50])
        translate([cx + dx, yb - 6, zc + dz]) rotate([-90, 0, 0])
            cylinder(d = 4, h = 6 + eps);
}


// ================= 4. modulo_cuello() =================
// Pilar inclinado hacia atrás; su extremo inferior queda apoyado en la base
module modulo_cuello() {
    color("#2c2c30")
    translate([cx, cuello_y_inf, cuello_z_inf - eps])
        rotate([-cuello_angulo, 0, 0])          // -X: la parte superior se va hacia +Y (atrás)
            translate([-cuello_ancho / 2, -cuello_prof / 2, 0])
                cube([cuello_ancho, cuello_prof, cuello_alto + eps]);
}


// ================= 5. modulo_base() =================
// Bloque plano con esquinas suavizadas mediante minkowski()
module modulo_base() {
    color("#2c2c30")
    translate([cx - base_ancho / 2 + base_radio,
               base_y_centro - base_prof / 2 + base_radio,
               0])
        minkowski() {
            cube([base_ancho - 2 * base_radio,
                  base_prof  - 2 * base_radio,
                  base_grosor / 2]);
            cylinder(r = base_radio, h = base_grosor / 2);
        }
}


// ================= ENSAMBLE =================
module monitor() {
    difference() {
        union() {
            modulo_pantalla();         // 1 y 2
            modulo_carcasa_trasera();  // 3
            union() {                  // 4 + 5: soporte
                modulo_cuello();
                modulo_base();
            }
        }
        detalles_traseros();           // 3. agujeros VESA
    }
}

monitor();

echo(str("Borde inferior del panel a ", panel_z, " mm de la mesa; alto total = ", panel_z + alto_z, " mm"));
