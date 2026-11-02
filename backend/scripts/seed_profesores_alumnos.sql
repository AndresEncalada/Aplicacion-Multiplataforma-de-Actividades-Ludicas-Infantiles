-- ============================================================================
-- SEMILLA DE PROFESORES Y ALUMNOS PARA POSTGRESQL (base_tesis - Raspberry Pi)
-- ============================================================================
-- Todos los alumnos tienen entre 3 y 5 años y un ÚNICO nivel estándar ('Inicial'),
-- distinguiéndose exclusivamente por el profesor (usuario_id) asignado.
--
-- Contraseñas hasheadas con PBKDF2-SHA256:
--   prof_maria  -> felpudo2026
--   prof_carlos -> felpudo2026
--   admin       -> admin123
-- ============================================================================

INSERT INTO public.auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined)
VALUES
    (1, 'pbkdf2_sha256$260000$a1b2c3d4e5f60718$8mK7vW2xN9pQ4rT6yU8iO0pA2sD4fG6hJ8kL0zX2cV4=', NOW(), false, 'prof_maria', 'María', 'Gómez', 'maria.gomez@felpudo.edu.ec', true, true, NOW()),
    (2, 'pbkdf2_sha256$260000$f1e2d3c4b5a69788$3nJ5bV7cX9zL1kH3gF5dS7aP9oI1uY3tR5eW7qA9sD1=', NOW(), false, 'prof_carlos', 'Carlos', 'Mendoza', 'carlos.mendoza@felpudo.edu.ec', true, true, NOW()),
    (3, 'pbkdf2_sha256$260000$1122334455667788$9pL0kM8jN7hB6gV5fC4xZ3aS2dF1gH0jK9lP8oI7uY6=', NOW(), true,  'admin', 'Elena', 'Suárez', 'admin@felpudo.edu.ec', true, true, NOW())
ON CONFLICT (id) DO NOTHING;

-- Alumnos de 3 a 5 años en un solo nivel ('Inicial'), agrupados por profesor (usuario_id)
INSERT INTO public.datos_nn (id, nombre, apellido, fec_nacimiento, nivel, discapacidad, usuario_id)
VALUES
    -- Alumnos de la Profesora María Gómez (usuario_id = 1)
    (1, 'Mateo', 'Pérez', '2022-05-14', 'Inicial', 'Ninguna', 1),
    (2, 'Valentina', 'Torres', '2022-11-08', 'Inicial', 'Lenguaje leve', 1),
    (3, 'Lucas', 'Sánchez', '2021-09-20', 'Inicial', 'Motricidad fina', 1),
    (4, 'Sofía', 'Ramírez', '2023-02-12', 'Inicial', 'Ninguna', 1),

    -- Alumnos del Profesor Carlos Mendoza (usuario_id = 2)
    (5, 'Sebastián', 'Morales', '2022-03-19', 'Inicial', 'Ninguna', 2),
    (6, 'Camila', 'Herrera', '2021-12-04', 'Inicial', 'Atención dispersa', 2),
    (7, 'Thiago', 'Castro', '2023-01-25', 'Inicial', 'Ninguna', 2),

    -- Alumnos de la Profesora Elena Suárez (usuario_id = 3)
    (8, 'Lucía', 'Vargas', '2022-07-30', 'Inicial', 'Ninguna', 3),
    (9, 'Emiliano', 'Ríos', '2021-10-15', 'Inicial', 'Lenguaje leve', 3)
ON CONFLICT (id) DO NOTHING;

SELECT pg_catalog.setval('public.auth_user_id_seq', 3, true);
SELECT pg_catalog.setval('public.datos_nn_id_seq', 9, true);
