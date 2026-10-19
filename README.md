# JePDF para Mac

Aplicación nativa de herramientas PDF en español, creada con SwiftUI, AppKit y PDFKit. Procesa los archivos en el equipo y no usa servicios externos ni dependencias de terceros.

## Ejecutar

Requiere macOS 13 o posterior y las herramientas de línea de comandos de Xcode con Swift 5.9 o posterior.

```sh
swift run JePDF
```

Para generar una aplicación que puedes abrir desde Finder:

```sh
zsh scripts/build-app.sh
open dist/JePDF.app
```

El script genera una app para la arquitectura del Mac donde se compila y la firma localmente. También crea `dist/JePDF.zip` sin atributos extendidos: si la carpeta del proyecto está sincronizada con iCloud, descomprime ese ZIP en una carpeta local antes de abrirlo para evitar que los metadatos de sincronización afecten a la firma. La distribución pública requiere configurar un identificador propio, firma Developer ID y notarización de Apple.

## Apariencia

El selector de la barra superior permite elegir **Claro**, **Oscuro** o **Sistema**. La preferencia se guarda entre aperturas y se aplica al catálogo, los paneles de herramientas y los diálogos nativos. El documento PDF conserva sus colores originales.

## Herramientas disponibles

- Unir PDF y ordenar los archivos antes de unirlos.
- Extraer páginas a un PDF; rangos como `1-3, 5`.
- Organizar páginas: reordenar, repetir o eliminar usando una lista como `3, 1, 2` o `5-1`.
- Comprimir mediante rasterización con calidad JPEG ajustable.
- Convertir JPG, PNG y TIFF a PDF.
- Exportar páginas de PDF a JPG en una carpeta nueva.
- Rotar todas las páginas o una selección.
- Añadir marcas de texto y números de página como anotaciones editables.
- Proteger con contraseña y generar copias sin contraseña con la clave actual.
- Extraer texto seleccionable a TXT.

La interfaz incluye selección de archivos, arrastrar archivos al área de carga, vista previa, búsqueda, filtros y acceso al resultado en Finder. El guardado impide elegir un archivo de entrada como destino.

## Límites de esta versión

La compresión convierte las páginas en imágenes: pierde texto seleccionable, enlaces y formularios; no garantiza reducir el tamaño. La exportación JPG usa 144 ppp y limita el lado más largo a 4096 px. Las marcas y la numeración no se aplanan y pueden retirarse con un editor PDF. En páginas que ya tengan una rotación, las anotaciones siguen las coordenadas internas del PDF.

Las conversiones a Office, el editor libre, las firmas y OCR aparecen como **Próximamente** y no simulan conversiones. PDFKit por sí solo no ofrece conversiones fieles a Office. No se implementa firma criptográfica. La contraseña de entrada se aplica a todos los archivos de una unión; para claves diferentes, desbloquéalos primero por separado. El proceso de exportación no puede cancelarse una vez iniciado.

## Verificar

```sh
swift run PDFCoreChecks
```

Las siete comprobaciones generan sus propios documentos y cubren rangos inválidos, orden y duplicación de páginas, rotación sin modificar el origen, unión, guardado, protección y copia sin contraseña, anotaciones y exportación de imágenes. La regresión de compresión compara el contenido antes y después del guardado en 16 combinaciones de orientación, giro, origen y márgenes. No requieren XCTest y funcionan con las herramientas de línea de comandos de Xcode.

## Estructura

- `Sources/PDFCore`: operaciones PDF independientes de la interfaz.
- `Sources/JePDF`: interfaz y flujo de exportación.
- `Tests/PDFCoreTests`: pruebas con documentos generados en memoria.
- `scripts/build-app.sh`: empaquetado de la aplicación macOS.

## Estado de validación

Versión experimental 0.1.3. La compresión ahora dibuja la imagen al tamaño físico original en vez de modificar la caja de una página de imagen; conserva la rotación y las cajas del PDF. Compilación optimizada para Apple Silicon y siete comprobaciones del motor superadas. La firma local del paquete ZIP se verificó después de extraerlo en una carpeta temporal. Se inspeccionaron visualmente el catálogo y el panel de herramientas; no se pudo confirmar el flujo completo de apertura y guardado mediante la automatización de ventanas, que empezó a devolver errores de tiempo de espera después de seleccionar un archivo. Ese recorrido sigue pendiente de una comprobación manual.

Copyright: je0azul5
