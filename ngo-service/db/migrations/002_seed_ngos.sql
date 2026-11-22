INSERT INTO ngos (name, email, cause, city) VALUES
('Anjos de Patas', 'contato@anjosdepatas.org', 'Proteção Animal', 'Osasco'),
('Educa Mais', 'info@educamais.org', 'Educação', 'São Paulo')
ON CONFLICT (email) DO NOTHING;
