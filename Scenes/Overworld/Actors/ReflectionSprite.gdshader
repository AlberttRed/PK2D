shader_type canvas_item;

uniform int hframes = 1;        // nº de columnas del spritesheet
uniform int current_frame = 0;  // índice del frame en horizontal

void fragment() {
    // tamaño real del frame en UV
    float frame_width_uv = 1.0 / float(hframes);

    // UV.x del frame dentro del spritesheet (global)
    float frame_start = frame_width_uv * float(current_frame);
    float frame_end   = frame_start + frame_width_uv;

    // convertir UV global → UV local (0→1)
    float local_x = (UV.x - frame_start) / frame_width_uv;

    // si el pixel no pertenece al frame → descartar
    if (local_x < 0.0 || local_x > 1.0) discard;

    // UV local completa
    vec2 fuv = vec2(local_x, UV.y);

    // muestrear el texel correcto
    vec4 tex = texture(TEXTURE, vec2(
        frame_start + fuv.x * frame_width_uv,
        UV.y
    ));

    if (tex.a < 0.01) discard;

    // PROBAMOS LA DIVISIÓN POR MITADES DEL FRAME:
    if (fuv.x < 0.5) {
        COLOR = vec4(1.0, 0.0, 0.0, 1.0);
    } else {
        COLOR = vec4(0.0, 0.0, 1.0, 1.0);
    }
}
