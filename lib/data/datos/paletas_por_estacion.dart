import '../../models/enums.dart';
import '../../models/paleta_model.dart';

/// Paletas de referencia por estación. Son la fuente cuando
/// `paletas/{estacion}` no está cargada en Firestore.
/// Mismos datos que `functions/src/datos/paletas.ts`: si cambias uno,
/// cambia el otro.
class PaletasPorEstacion {
  PaletasPorEstacion._();

  static Paleta de(EstacionColor estacion) => switch (estacion) {
    EstacionColor.primavera => primavera,
    EstacionColor.verano => verano,
    EstacionColor.otono => otono,
    EstacionColor.invierno => invierno,
  };

  static const todas = [primavera, verano, otono, invierno];

  static const primavera = Paleta(
    estacion: EstacionColor.primavera,
    neutros: [
      ColorPaleta(nombre: 'Camel claro', hex: '#D2A86E'),
      ColorPaleta(nombre: 'Marfil', hex: '#FFF8E7'),
      ColorPaleta(nombre: 'Beige dorado', hex: '#E3C59B'),
      ColorPaleta(nombre: 'Gris cálido', hex: '#A89F91'),
      ColorPaleta(nombre: 'Azul marino claro', hex: '#3B5998'),
      ColorPaleta(nombre: 'Arena', hex: '#E2CBA4'),
    ],
    maquillaje: MaquillajePaleta(
      labiales: [
        ColorPaleta(nombre: 'Coral', hex: '#FF6F61'),
        ColorPaleta(nombre: 'Melocotón', hex: '#F7A07A'),
        ColorPaleta(nombre: 'Rojo amapola', hex: '#E35335'),
        ColorPaleta(nombre: 'Rosa salmón', hex: '#FA8072'),
        ColorPaleta(nombre: 'Durazno brillante', hex: '#FF9A76'),
        ColorPaleta(nombre: 'Rojo coral', hex: '#F2552C'),
      ],
      rubores: [
        ColorPaleta(nombre: 'Melocotón', hex: '#FFB07C'),
        ColorPaleta(nombre: 'Coral suave', hex: '#F4A38A'),
        ColorPaleta(nombre: 'Albaricoque', hex: '#FBCEB1'),
        ColorPaleta(nombre: 'Coral rosado', hex: '#F7967E'),
        ColorPaleta(nombre: 'Durazno dorado', hex: '#F9B98A'),
      ],
      sombras: [
        ColorPaleta(nombre: 'Bronce claro', hex: '#C9A66B'),
        ColorPaleta(nombre: 'Dorado', hex: '#D4AF37'),
        ColorPaleta(nombre: 'Verde oliva claro', hex: '#A3B86C'),
        ColorPaleta(nombre: 'Turquesa', hex: '#30D5C8'),
        ColorPaleta(nombre: 'Champán', hex: '#F1D7A8'),
        ColorPaleta(nombre: 'Menta cálida', hex: '#98D7A5'),
      ],
    ),
    coloresRecomendados: [
      ColorPaleta(nombre: 'Coral', hex: '#FF7F50'),
      ColorPaleta(nombre: 'Melocotón', hex: '#FFB07C'),
      ColorPaleta(nombre: 'Amarillo mantequilla', hex: '#F8DE7E'),
      ColorPaleta(nombre: 'Verde manzana', hex: '#8DB600'),
      ColorPaleta(nombre: 'Turquesa cálido', hex: '#30D5C8'),
      ColorPaleta(nombre: 'Azul aguamarina', hex: '#5FB3C5'),
      ColorPaleta(nombre: 'Rosa salmón', hex: '#FA8072'),
      ColorPaleta(nombre: 'Camel claro', hex: '#D2A86E'),
      ColorPaleta(nombre: 'Marfil', hex: '#FFF8E7'),
      ColorPaleta(nombre: 'Rojo amapola', hex: '#E35335'),
      ColorPaleta(nombre: 'Mandarina', hex: '#FF9E44'),
      ColorPaleta(nombre: 'Verde lima', hex: '#B5D33D'),
      ColorPaleta(nombre: 'Amarillo limón', hex: '#FFE066'),
      ColorPaleta(nombre: 'Coral claro', hex: '#F88379'),
      ColorPaleta(nombre: 'Menta cálida', hex: '#98D7A5'),
      ColorPaleta(nombre: 'Dorado claro', hex: '#E6BE5A'),
    ],
    coloresEvitar: [
      ColorPaleta(nombre: 'Negro', hex: '#000000'),
      ColorPaleta(nombre: 'Gris carbón', hex: '#36454F'),
      ColorPaleta(nombre: 'Borgoña', hex: '#800020'),
      ColorPaleta(nombre: 'Azul marino oscuro', hex: '#0B1F3A'),
      ColorPaleta(nombre: 'Blanco óptico', hex: '#F4F4F8'),
      ColorPaleta(nombre: 'Ciruela', hex: '#5E2750'),
    ],
  );

  static const verano = Paleta(
    estacion: EstacionColor.verano,
    neutros: [
      ColorPaleta(nombre: 'Gris perla', hex: '#C9C9D1'),
      ColorPaleta(nombre: 'Azul marino suave', hex: '#3F4E6E'),
      ColorPaleta(nombre: 'Blanco suave', hex: '#F5F3EF'),
      ColorPaleta(nombre: 'Gris topo', hex: '#8B8589'),
      ColorPaleta(nombre: 'Rosa beige', hex: '#D9C2BA'),
      ColorPaleta(nombre: 'Gris azulado', hex: '#A3B1C2'),
    ],
    maquillaje: MaquillajePaleta(
      labiales: [
        ColorPaleta(nombre: 'Rosa empolvado', hex: '#D8A1B0'),
        ColorPaleta(nombre: 'Malva', hex: '#B784A7'),
        ColorPaleta(nombre: 'Frambuesa suave', hex: '#C25A7C'),
        ColorPaleta(nombre: 'Rosa frío', hex: '#E7A1B0'),
        ColorPaleta(nombre: 'Rosa palo', hex: '#D99AA5'),
        ColorPaleta(nombre: 'Ciruela suave', hex: '#8E5A7A'),
      ],
      rubores: [
        ColorPaleta(nombre: 'Rosa suave', hex: '#F4C2C2'),
        ColorPaleta(nombre: 'Malva claro', hex: '#D8A7B1'),
        ColorPaleta(nombre: 'Rosa té', hex: '#E5B3BB'),
        ColorPaleta(nombre: 'Rosa orquídea', hex: '#DDA0B4'),
        ColorPaleta(nombre: 'Lila rosado', hex: '#CFA3C1'),
      ],
      sombras: [
        ColorPaleta(nombre: 'Gris paloma', hex: '#A7A9AC'),
        ColorPaleta(nombre: 'Lavanda', hex: '#B4A7D6'),
        ColorPaleta(nombre: 'Taupe', hex: '#8B8589'),
        ColorPaleta(nombre: 'Azul pizarra', hex: '#6A7FA0'),
        ColorPaleta(nombre: 'Ciruela suave', hex: '#8E6C8A'),
        ColorPaleta(nombre: 'Azul acero', hex: '#7A93AC'),
      ],
    ),
    coloresRecomendados: [
      ColorPaleta(nombre: 'Rosa empolvado', hex: '#D8A1B0'),
      ColorPaleta(nombre: 'Lavanda', hex: '#B4A7D6'),
      ColorPaleta(nombre: 'Azul cielo', hex: '#87AFC7'),
      ColorPaleta(nombre: 'Azul pizarra', hex: '#6A7FA0'),
      ColorPaleta(nombre: 'Malva', hex: '#B784A7'),
      ColorPaleta(nombre: 'Frambuesa suave', hex: '#C25A7C'),
      ColorPaleta(nombre: 'Verde salvia', hex: '#9CAF88'),
      ColorPaleta(nombre: 'Gris perla', hex: '#C9C9D1'),
      ColorPaleta(nombre: 'Blanco suave', hex: '#F5F3EF'),
      ColorPaleta(nombre: 'Azul marino suave', hex: '#3F4E6E'),
      ColorPaleta(nombre: 'Rosa palo', hex: '#E8C4C8'),
      ColorPaleta(nombre: 'Verde agua', hex: '#A8D5C8'),
      ColorPaleta(nombre: 'Azul acero', hex: '#7A93AC'),
      ColorPaleta(nombre: 'Orquídea suave', hex: '#C3A1C9'),
      ColorPaleta(nombre: 'Ciruela suave', hex: '#8E6C8A'),
      ColorPaleta(nombre: 'Gris azulado', hex: '#A3B1C2'),
    ],
    coloresEvitar: [
      ColorPaleta(nombre: 'Naranja', hex: '#F28C28'),
      ColorPaleta(nombre: 'Mostaza', hex: '#D4A017'),
      ColorPaleta(nombre: 'Verde oliva', hex: '#708238'),
      ColorPaleta(nombre: 'Marrón dorado', hex: '#996515'),
      ColorPaleta(nombre: 'Negro', hex: '#000000'),
      ColorPaleta(nombre: 'Rojo tomate', hex: '#E5361F'),
    ],
  );

  static const otono = Paleta(
    estacion: EstacionColor.otono,
    neutros: [
      ColorPaleta(nombre: 'Camel', hex: '#C19A6B'),
      ColorPaleta(nombre: 'Chocolate', hex: '#5C3A21'),
      ColorPaleta(nombre: 'Crema', hex: '#F3E5C0'),
      ColorPaleta(nombre: 'Caqui', hex: '#A39264'),
      ColorPaleta(nombre: 'Verde oliva', hex: '#708238'),
      ColorPaleta(nombre: 'Arena tostada', hex: '#C9B28A'),
    ],
    maquillaje: MaquillajePaleta(
      labiales: [
        ColorPaleta(nombre: 'Terracota', hex: '#C8553D'),
        ColorPaleta(nombre: 'Ladrillo', hex: '#A0522D'),
        ColorPaleta(nombre: 'Nude cálido', hex: '#C08A6B'),
        ColorPaleta(nombre: 'Burdeos cálido', hex: '#7B2D26'),
        ColorPaleta(nombre: 'Canela', hex: '#B5653F'),
        ColorPaleta(nombre: 'Chocolate rojizo', hex: '#6E2C1F'),
      ],
      rubores: [
        ColorPaleta(nombre: 'Terracota suave', hex: '#D2876B'),
        ColorPaleta(nombre: 'Bronce', hex: '#CD7F32'),
        ColorPaleta(nombre: 'Durazno tostado', hex: '#E3A27C'),
        ColorPaleta(nombre: 'Canela', hex: '#C27C5A'),
        ColorPaleta(nombre: 'Melocotón tostado', hex: '#D9906B'),
      ],
      sombras: [
        ColorPaleta(nombre: 'Cobre', hex: '#B87333'),
        ColorPaleta(nombre: 'Bronce', hex: '#CD7F32'),
        ColorPaleta(nombre: 'Verde bosque', hex: '#2E5A3A'),
        ColorPaleta(nombre: 'Chocolate', hex: '#5C3A21'),
        ColorPaleta(nombre: 'Oro viejo', hex: '#B08D57'),
        ColorPaleta(nombre: 'Verde musgo', hex: '#6B7B3A'),
      ],
    ),
    coloresRecomendados: [
      ColorPaleta(nombre: 'Terracota', hex: '#C8553D'),
      ColorPaleta(nombre: 'Mostaza', hex: '#D4A017'),
      ColorPaleta(nombre: 'Verde oliva', hex: '#708238'),
      ColorPaleta(nombre: 'Camel', hex: '#C19A6B'),
      ColorPaleta(nombre: 'Óxido', hex: '#B7410E'),
      ColorPaleta(nombre: 'Chocolate', hex: '#5C3A21'),
      ColorPaleta(nombre: 'Verde bosque', hex: '#2E5A3A'),
      ColorPaleta(nombre: 'Petróleo', hex: '#1F5F6B'),
      ColorPaleta(nombre: 'Crema', hex: '#F3E5C0'),
      ColorPaleta(nombre: 'Burdeos cálido', hex: '#7B2D26'),
      ColorPaleta(nombre: 'Calabaza', hex: '#D2691E'),
      ColorPaleta(nombre: 'Verde musgo', hex: '#6B7B3A'),
      ColorPaleta(nombre: 'Ámbar', hex: '#C68E17'),
      ColorPaleta(nombre: 'Caqui', hex: '#A39264'),
      ColorPaleta(nombre: 'Teja', hex: '#B5523B'),
      ColorPaleta(nombre: 'Azul pato', hex: '#2F6F73'),
    ],
    coloresEvitar: [
      ColorPaleta(nombre: 'Fucsia', hex: '#B0005A'),
      ColorPaleta(nombre: 'Azul eléctrico', hex: '#2C75FF'),
      ColorPaleta(nombre: 'Rosa chicle', hex: '#FF77BC'),
      ColorPaleta(nombre: 'Gris frío', hex: '#A9B0BB'),
      ColorPaleta(nombre: 'Blanco óptico', hex: '#F4F4F8'),
      ColorPaleta(nombre: 'Lavanda', hex: '#B4A7D6'),
    ],
  );

  static const invierno = Paleta(
    estacion: EstacionColor.invierno,
    neutros: [
      ColorPaleta(nombre: 'Negro', hex: '#000000'),
      ColorPaleta(nombre: 'Carbón', hex: '#2B2B2B'),
      ColorPaleta(nombre: 'Blanco óptico', hex: '#F4F4F8'),
      ColorPaleta(nombre: 'Azul marino', hex: '#1A2A4F'),
      ColorPaleta(nombre: 'Gris frío', hex: '#A9B0BB'),
      ColorPaleta(nombre: 'Gris plata', hex: '#B9BEC6'),
    ],
    maquillaje: MaquillajePaleta(
      labiales: [
        ColorPaleta(nombre: 'Rojo frambuesa', hex: '#C2185B'),
        ColorPaleta(nombre: 'Rojo clásico', hex: '#B3001B'),
        ColorPaleta(nombre: 'Vino', hex: '#7F1734'),
        ColorPaleta(nombre: 'Fucsia', hex: '#B0005A'),
        ColorPaleta(nombre: 'Rojo verdadero', hex: '#C8102E'),
        ColorPaleta(nombre: 'Ciruela intensa', hex: '#6B1F4A'),
      ],
      rubores: [
        ColorPaleta(nombre: 'Rosa frío', hex: '#E75480'),
        ColorPaleta(nombre: 'Frambuesa suave', hex: '#C25A7C'),
        ColorPaleta(nombre: 'Ciruela claro', hex: '#A05C7B'),
        ColorPaleta(nombre: 'Rosa intenso', hex: '#D63A7A'),
        ColorPaleta(nombre: 'Fucsia suave', hex: '#C2468E'),
      ],
      sombras: [
        ColorPaleta(nombre: 'Plata', hex: '#C0C0C0'),
        ColorPaleta(nombre: 'Gris carbón', hex: '#36454F'),
        ColorPaleta(nombre: 'Ciruela', hex: '#5E2750'),
        ColorPaleta(nombre: 'Azul zafiro', hex: '#0F52BA'),
        ColorPaleta(nombre: 'Púrpura real', hex: '#6A1B9A'),
        ColorPaleta(nombre: 'Azul real', hex: '#2747A8'),
      ],
    ),
    coloresRecomendados: [
      ColorPaleta(nombre: 'Azul clásico', hex: '#0F4C81'),
      ColorPaleta(nombre: 'Fucsia', hex: '#B0005A'),
      ColorPaleta(nombre: 'Esmeralda', hex: '#00796B'),
      ColorPaleta(nombre: 'Vino', hex: '#7F1734'),
      ColorPaleta(nombre: 'Carbón', hex: '#2B2B2B'),
      ColorPaleta(nombre: 'Blanco óptico', hex: '#F4F4F8'),
      ColorPaleta(nombre: 'Rojo frambuesa', hex: '#C2185B'),
      ColorPaleta(nombre: 'Azul marino', hex: '#1A2A4F'),
      ColorPaleta(nombre: 'Negro', hex: '#000000'),
      ColorPaleta(nombre: 'Violeta intenso', hex: '#5B2C83'),
      ColorPaleta(nombre: 'Rojo verdadero', hex: '#C8102E'),
      ColorPaleta(nombre: 'Azul real', hex: '#2747A8'),
      ColorPaleta(nombre: 'Púrpura real', hex: '#6A1B9A'),
      ColorPaleta(nombre: 'Turquesa frío', hex: '#008C95'),
      ColorPaleta(nombre: 'Rosa hielo', hex: '#F2D7E3'),
      ColorPaleta(nombre: 'Verde pino', hex: '#0B5D4B'),
    ],
    coloresEvitar: [
      ColorPaleta(nombre: 'Naranja', hex: '#F28C28'),
      ColorPaleta(nombre: 'Mostaza', hex: '#D4A017'),
      ColorPaleta(nombre: 'Camel', hex: '#C19A6B'),
      ColorPaleta(nombre: 'Verde oliva', hex: '#708238'),
      ColorPaleta(nombre: 'Beige', hex: '#E8D8B8'),
      ColorPaleta(nombre: 'Marrón dorado', hex: '#996515'),
    ],
  );
}
