#!/usr/bin/env python3
"""
exportar_step.py — Convierte modelos OpenSCAD (.scad) a STEP (.step).

Flujo por cada archivo:
  1. OpenSCAD renderiza el .scad y exporta un STL temporal.
  2. OpenCascade (vía CadQuery/OCP) lee la malla, cose los triángulos
     y la convierte en un sólido cerrado.
  3. Se unen las caras coplanares (opcional) para aligerar el archivo.
  4. Se guarda el .step en la carpeta de destino.

Uso:
  python exportar_step.py ENTRADA [-o SALIDA] [opciones]

  ENTRADA  archivo .scad o carpeta con archivos .scad
  -o       carpeta de destino (por defecto, la misma carpeta del .scad)

Ejemplos:
  python exportar_step.py torre_pc.scad
  python exportar_step.py ./modelos3d -o ./modelos_step
  python exportar_step.py ./modelos3d -o ./modelos_step --recursivo --fn 32

Requisitos: OpenSCAD instalado y `pip install cadquery`.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

try:
    from OCP.BRep import BRep_Builder
    from OCP.BRepBuilderAPI import BRepBuilderAPI_MakeSolid, BRepBuilderAPI_Sewing
    from OCP.Message import Message, Message_Gravity
    from OCP.BRepCheck import BRepCheck_Analyzer
    from OCP.BRepGProp import BRepGProp
    from OCP.Bnd import Bnd_Box
    from OCP.BRepBndLib import BRepBndLib
    from OCP.GProp import GProp_GProps
    from OCP.IFSelect import IFSelect_RetDone
    from OCP.Interface import Interface_Static
    from OCP.ShapeFix import ShapeFix_Solid
    from OCP.ShapeUpgrade import ShapeUpgrade_UnifySameDomain
    from OCP.StlAPI import StlAPI_Reader
    from OCP.STEPControl import STEPControl_AsIs, STEPControl_Writer
    from OCP.TopAbs import TopAbs_FACE, TopAbs_SHELL, TopAbs_SOLID
    from OCP.BRepLib import BRepLib
    from OCP.TopAbs import TopAbs_EDGE
    from OCP.TopExp import TopExp, TopExp_Explorer
    from OCP.TopoDS import TopoDS, TopoDS_Compound, TopoDS_Shape, TopoDS_Shell
    from OCP.TopTools import (TopTools_IndexedDataMapOfShapeListOfShape,
                              TopTools_IndexedMapOfShape)
except ImportError:
    sys.exit("Error: no se encontró OpenCascade (OCP). Instálalo con:  pip install cadquery")


# --------------------------------------------------------------------------
#  OpenSCAD
# --------------------------------------------------------------------------
RUTAS_OPENSCAD = [
    r"C:\Program Files\OpenSCAD\openscad.com",
    r"C:\Program Files\OpenSCAD\openscad.exe",
    r"C:\Program Files (x86)\OpenSCAD\openscad.com",
    "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD",
    "/usr/bin/openscad",
    "/usr/local/bin/openscad",
]


def buscar_openscad(ruta_usuario=None):
    if ruta_usuario:
        if Path(ruta_usuario).is_file():
            return ruta_usuario
        sys.exit(f"Error: no existe el ejecutable de OpenSCAD indicado: {ruta_usuario}")
    for nombre in ("openscad.com", "openscad"):
        encontrado = shutil.which(nombre)
        if encontrado:
            return encontrado
    for ruta in RUTAS_OPENSCAD:
        if Path(ruta).is_file():
            return ruta
    sys.exit("Error: no se encontró OpenSCAD. Indica la ruta con --openscad \"RUTA\\openscad.com\"")


def scad_a_stl(openscad, scad, stl, fn=None, definiciones=()):
    cmd = [openscad, "-o", str(stl)]
    if fn:
        cmd += ["-D", f"$fn={fn}"]
    for d in definiciones:
        cmd += ["-D", d]
    cmd.append(str(scad))
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0 or not Path(stl).is_file() or Path(stl).stat().st_size == 0:
        raise RuntimeError("OpenSCAD falló:\n" + (res.stderr or res.stdout).strip())
    avisos = [l for l in res.stderr.splitlines() if "WARNING" in l.upper()]
    return avisos


# --------------------------------------------------------------------------
#  OpenCascade: STL -> sólido -> STEP
# --------------------------------------------------------------------------
def contar(shape, tipo):
    n, exp = 0, TopExp_Explorer(shape, tipo)
    while exp.More():
        n += 1
        exp.Next()
    return n


def separar_por_aristas(cascara, builder):
    """Divide una cáscara en grupos de caras conectadas por aristas.

    OpenSCAD puede generar piezas que se tocan solo en un vértice; la costura
    las deja en una misma cáscara y OpenCascade la marca como inválida
    ("multi-conexión"). Separándolas, cada una es un sólido válido.
    """
    caras = TopTools_IndexedMapOfShape()
    TopExp.MapShapes_s(cascara, TopAbs_FACE, caras)
    n = caras.Extent()
    padre = list(range(n + 1))

    def raiz(i):
        while padre[i] != i:
            padre[i] = padre[padre[i]]
            i = padre[i]
        return i

    arista_caras = TopTools_IndexedDataMapOfShapeListOfShape()
    TopExp.MapShapesAndAncestors_s(cascara, TopAbs_EDGE, TopAbs_FACE, arista_caras)
    for k in range(1, arista_caras.Extent() + 1):
        ids = [caras.FindIndex(f) for f in arista_caras.FindFromIndex(k)]
        for j in ids[1:]:
            a, b = raiz(ids[0]), raiz(j)
            if a != b:
                padre[b] = a

    grupos = {}
    for i in range(1, n + 1):
        grupos.setdefault(raiz(i), []).append(i)
    if len(grupos) == 1:
        return [cascara]

    resultado = []
    for ids in grupos.values():
        nueva = TopoDS_Shell()
        builder.MakeShell(nueva)
        for i in ids:
            builder.Add(nueva, caras.FindKey(i))
        nueva.Closed(True)
        resultado.append(nueva)
    return resultado


def stl_a_solido(stl, tolerancia=1e-3, unir_caras=True):
    # 1. Leer la malla (cada triángulo se vuelve una cara)
    malla = TopoDS_Shape()
    if not StlAPI_Reader().Read(malla, str(stl)):
        raise RuntimeError("No se pudo leer el STL generado.")

    # 2. Coser triángulos -> cáscaras cerradas
    cosedor = BRepBuilderAPI_Sewing(tolerancia)
    cosedor.Add(malla)
    cosedor.Perform()
    cosido = cosedor.SewedShape()

    # 3. Cada superficie cerrada -> un sólido independiente.
    #    (Un modelo puede tener piezas separadas: ventiladores, brazos, etc.)
    builder = BRep_Builder()
    compuesto = TopoDS_Compound()
    builder.MakeCompound(compuesto)
    n_piezas = 0
    exp = TopExp_Explorer(cosido, TopAbs_SHELL)
    cascaras = []
    while exp.More():
        cascaras += separar_por_aristas(TopoDS.Shell_s(exp.Current()), builder)
        exp.Next()

    for cascara in cascaras:
        pieza = BRepBuilderAPI_MakeSolid(cascara).Solid()
        # Orienta las normales hacia afuera (rápido); si falla, usa el método lento
        if not BRepLib.OrientClosedSolid_s(pieza):
            fix = ShapeFix_Solid(pieza)
            fix.Perform()
            pieza = fix.Solid()

        # 4. Unir caras coplanares (aligera mucho el archivo)
        if unir_caras:
            unif = ShapeUpgrade_UnifySameDomain(pieza, True, True, False)
            unif.Build()
            pieza = unif.Shape()

        builder.Add(compuesto, pieza)
        n_piezas += 1

    if n_piezas == 0:
        raise RuntimeError("La malla no formó ninguna superficie cerrada.")

    forma = compuesto
    if n_piezas == 1:   # una sola pieza: se exporta el sólido directamente
        it = TopExp_Explorer(compuesto, TopAbs_SOLID)
        forma = it.Current() if it.More() else compuesto
    return forma, n_piezas


def silenciar_opencascade():
    """Oculta las estadísticas que OpenCascade imprime al escribir el STEP."""
    printers = Message.DefaultMessenger_s().Printers()
    for i in range(1, printers.Length() + 1):
        printers.Value(i).SetTraceLevel(Message_Gravity.Message_Fail)


def guardar_step(forma, destino, nombre_producto):
    Interface_Static.SetCVal_s("write.step.unit", "MM")
    Interface_Static.SetCVal_s("write.step.product.name", nombre_producto)
    silenciar_opencascade()
    escritor = STEPControl_Writer()
    if escritor.Transfer(forma, STEPControl_AsIs) != IFSelect_RetDone:
        raise RuntimeError("No se pudo transferir la geometría al formato STEP.")
    if escritor.Write(str(destino)) != IFSelect_RetDone:
        raise RuntimeError(f"No se pudo escribir {destino}")


def resumen(forma):
    caja = Bnd_Box()
    BRepBndLib.Add_s(forma, caja)
    x0, y0, z0, x1, y1, z1 = caja.Get()
    props = GProp_GProps()
    BRepGProp.VolumeProperties_s(forma, props)
    return {
        "medidas": (x1 - x0, y1 - y0, z1 - z0),
        "volumen_cm3": props.Mass() / 1000.0,
        "caras": contar(forma, TopAbs_FACE),
        "valido": BRepCheck_Analyzer(forma).IsValid(),
    }


# --------------------------------------------------------------------------
#  Programa principal
# --------------------------------------------------------------------------
def convertir(openscad, scad, carpeta_destino, args):
    destino = carpeta_destino / (scad.stem + ".step")
    if destino.exists() and not args.sobrescribir:
        print(f"  ⏭  {scad.name}: ya existe {destino.name} (usa --sobrescribir)")
        return "omitido"

    t0 = time.time()
    with tempfile.TemporaryDirectory() as tmp:
        stl = Path(tmp) / (scad.stem + ".stl")
        print(f"  ▶  {scad.name}: renderizando con OpenSCAD...", flush=True)
        avisos = scad_a_stl(openscad, scad, stl, args.fn, args.define)
        for a in avisos:
            print(f"     ⚠ {a}")
        print(f"     convirtiendo a sólido...", flush=True)
        forma, piezas = stl_a_solido(stl, args.tolerancia, not args.sin_unir_caras)

    destino.parent.mkdir(parents=True, exist_ok=True)
    guardar_step(forma, destino, scad.stem)
    r = resumen(forma)
    mx, my, mz = r["medidas"]
    estado = "válido" if r["valido"] else "⚠ revisar en CAD"
    print(f"  ✔  {destino}  ({time.time() - t0:.1f} s)")
    print(f"     {mx:.2f} × {my:.2f} × {mz:.2f} mm | {r['volumen_cm3']:.1f} cm³ | "
          f"{r['caras']} caras | {piezas} pieza(s) | sólido {estado}")
    return "ok"


def main():
    p = argparse.ArgumentParser(
        description="Convierte archivos OpenSCAD (.scad) a STEP (.step).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Ejemplo:\n  python exportar_step.py ./modelos3d -o ./modelos_step",
    )
    p.add_argument("entrada", help="archivo .scad o carpeta con archivos .scad")
    p.add_argument("-o", "--salida", help="carpeta de destino (por defecto, junto a cada .scad)")
    p.add_argument("-r", "--recursivo", action="store_true",
                   help="busca .scad también en subcarpetas (mantiene la estructura)")
    p.add_argument("--fn", type=int, help="fuerza $fn (menos = archivo más liviano, curvas más facetadas)")
    p.add_argument("-D", "--define", action="append", default=[], metavar="VAR=VALOR",
                   help="sobrescribe una variable del .scad, ej. -D alto_z=300 (se puede repetir)")
    p.add_argument("--tolerancia", type=float, default=1e-3, help="tolerancia de costura en mm (def. 0.001)")
    p.add_argument("--sin-unir-caras", action="store_true", help="no fusionar caras coplanares")
    p.add_argument("--sobrescribir", action="store_true", help="reemplaza los .step existentes")
    p.add_argument("--openscad", help="ruta al ejecutable de OpenSCAD")
    args = p.parse_args()

    entrada = Path(args.entrada).resolve()
    if entrada.is_file():
        if entrada.suffix.lower() != ".scad":
            sys.exit("Error: el archivo de entrada debe ser .scad")
        archivos, base = [entrada], entrada.parent
    elif entrada.is_dir():
        patron = "**/*.scad" if args.recursivo else "*.scad"
        archivos, base = sorted(entrada.glob(patron)), entrada
    else:
        sys.exit(f"Error: no existe {entrada}")

    if not archivos:
        sys.exit(f"No se encontraron archivos .scad en {entrada}")

    openscad = buscar_openscad(args.openscad)
    salida = Path(args.salida).resolve() if args.salida else None

    print(f"OpenSCAD: {openscad}")
    print(f"Archivos: {len(archivos)}  →  destino: {salida or 'junto a cada .scad'}\n")

    resultados = {"ok": 0, "omitido": 0, "error": 0}
    for scad in archivos:
        carpeta = (salida / scad.parent.relative_to(base)) if salida else scad.parent
        try:
            resultados[convertir(openscad, scad, carpeta, args)] += 1
        except Exception as e:
            resultados["error"] += 1
            print(f"  ✘  {scad.name}: {e}")
        print()

    print(f"Listo: {resultados['ok']} convertidos, {resultados['omitido']} omitidos, "
          f"{resultados['error']} con error.")
    sys.exit(1 if resultados["error"] else 0)


if __name__ == "__main__":
    main()
