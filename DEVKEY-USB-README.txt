DEVKEY 2.0
==========

La guia vigente de instalacion, autenticacion, seguridad, Guardian,
Git, proyectos, backups y limitaciones esta en README.md.

Inicio: ejecuta Launcher\DevKey.bat o Launcher\DevKey.ps1.
El launcher calcula las rutas desde su ubicacion; no depende de D:.

Ubicacion actual esperada del token: unlock.k3y en la raiz USB.
La carpeta DevKey debe estar junto a Apps, Data y Projects.
La unidad de referencia de este checkout no contiene unlock.k3y,
por lo que el launcher no concedera acceso hasta conectar el token
original con el SHA-256 esperado.
