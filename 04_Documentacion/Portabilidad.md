# Abrir y verificar la entrega

## Inventor

1. Extrae el proyecto completo a una carpeta local. En Inventor 2025.3, activa el archivo `Banda_Transportadora_V21.ipj`. Su espacio de trabajo es la propia carpeta de CAD. [Rutas de búsqueda de proyectos de Inventor](https://help.autodesk.com/cloudhelp/2020/ENU/Inventor-Help/files/GUID-0F34FEBE-4A2A-4494-A869-FC904F15F2BE.htm)
2. Abre `ESAMBLAJECOMPLETO_VALIDADO_SIMULACION_V2.iam`. El grafo incluye 44 documentos CAD y referencias a seis archivos del estudio FEA ya vinculado. Las apariencias personalizadas están en las piezas y sus tres mapas PNG están en `Texturas`.
3. Si Inventor solicita localizar una imagen en otro equipo, selecciona el archivo del mismo nombre dentro de `Texturas`. Inventor también permite indicar una carpeta compartida de texturas en **Opciones de aplicación → Archivos → Carpeta de texturas**. [Soporte de Autodesk sobre vínculos de texturas](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/How-to-recreate-links-between-textures-of-appearances-and-images.html)

Las huellas de los archivos entregados están en [Verificacion/Integridad-V2.csv](<../01_CAD/BANDA TRANSPORTADORA VALIDACION MECANICA V2/Verificacion/Integridad-V2.csv>). Las referencias de Inventor y los resultados de la comparación mecánica se conservan junto al informe técnico.

## CoppeliaSim

Abre `EXPORTACION_COPPELIASIM/Banda_clasificadora_V2.ttt` en **CoppeliaSim Edu 4.10.0**. El proyecto incluye `Manifiesto.json`, las 41 mallas STL en milímetros, el STEP, los parámetros de la dinámica y el registro de 16 casos. La escena está lista para abrir con el modelo ya construido.

Los archivos `Dinamica-V21.lua` y `Control-V21.lua` contienen el modelo y el control de la escena. `Crear-escena-V21.lua` reconstruye la escena desde el manifiesto y `Validar-escena-V21.lua` inicia los ensayos configurados. El lanzador PowerShell conserva las dos opciones.

```powershell
.\Scripts\Ejecutar-Coppelia-V21.ps1 -Modo validar
```

Corre el lanzador desde otra copia de la carpeta CAD. Una reproducción genera registros y reemplaza `Resultados-V21.json` en esa copia. Indica `-Instalacion` si CoppeliaSim Edu está instalado en otra ruta. El lanzador usa el motor Lua y las bibliotecas incluidas con CoppeliaSim. [Manual de opciones de CoppeliaSim](https://manual.coppeliarobotics.com/en/commandLine.htm)
