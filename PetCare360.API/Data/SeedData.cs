using PetCare360.API.Models;

namespace PetCare360.API.Data
{
    
    public static class SeedData
    {
        public static void Initialize(AppDbContext db)
        {
            
            if (db.Tutores.Any()) return;

            
            var tutor1 = new Tutor
            {
                NmTutor = "Murillo Fernandes Carapia",
                Cpf = "123.456.789-00",
                Email = "murillo@petcare360.com.br",
                Telefone = "(11) 99999-0001",
                Endereco = "Av. Lins de Vasconcelos, 1222 - Cambuci, Sao Paulo/SP"
            };
            var tutor2 = new Tutor
            {
                NmTutor = "Ana Beatriz Souza",
                Cpf = "987.654.321-00",
                Email = "ana.souza@petcare360.com.br",
                Telefone = "(11) 99999-0002",
                Endereco = "R. Augusta, 1500 - Consolacao, Sao Paulo/SP"
            };
            db.Tutores.AddRange(tutor1, tutor2);
            db.SaveChanges();

            
            var clinica1 = new Clinica
            {
                NmClinica = "CLYVO VET - Unidade Paulista",
                Cnpj = "12.345.678/0001-99",
                Endereco = "Av. Paulista, 1500 - Bela Vista, Sao Paulo/SP",
                Telefone = "(11) 3000-1000",
                Email = "paulista@clyvovet.com.br"
            };
            var clinica2 = new Clinica
            {
                NmClinica = "PetCare 360 - Unidade Vila Mariana",
                Cnpj = "98.765.432/0001-11",
                Endereco = "R. Domingos de Morais, 800 - Vila Mariana, Sao Paulo/SP",
                Telefone = "(11) 3000-2000",
                Email = "vilamariana@petcare360.com.br"
            };
            db.Clinicas.AddRange(clinica1, clinica2);
            db.SaveChanges();

            
            var pet1 = new Pet
            {
                NmPet = "Rex",
                Especie = "Cachorro",
                Raca = "Labrador Retriever",
                DtNascimento = new DateTime(2020, 5, 10),
                Peso = 28.50m,
                IdTutor = tutor1.IdTutor
            };
            var pet2 = new Pet
            {
                NmPet = "Mia",
                Especie = "Gato",
                Raca = "Siames",
                DtNascimento = new DateTime(2022, 8, 15),
                Peso = 4.20m,
                IdTutor = tutor2.IdTutor
            };
            db.Pets.AddRange(pet1, pet2);
            db.SaveChanges();

            
            var consulta1 = new Consulta
            {
                DtConsulta = DateTime.Now.AddDays(-30),
                Descricao = "Check-up anual de rotina, atualizacao de vacinas e exames preventivos",
                Diagnostico = "Pet saudavel - sem alteracoes clinicas significativas",
                IdPet = pet1.IdPet,
                IdClinica = clinica1.IdClinica
            };
            var consulta2 = new Consulta
            {
                DtConsulta = DateTime.Now.AddDays(-7),
                Descricao = "Consulta para analise de coceira excessiva e queda de pelo localizada",
                Diagnostico = "Dermatite leve por alergia alimentar - tratamento topico iniciado",
                IdPet = pet2.IdPet,
                IdClinica = clinica2.IdClinica
            };
            db.Consultas.AddRange(consulta1, consulta2);
            db.SaveChanges();

           
            db.Vacinas.AddRange(
                new Vacina
                {
                    NmVacina = "V10 (Multipla Canina)",
                    Fabricante = "Zoetis",
                    DtAplicacao = consulta1.DtConsulta,
                    DtProximaDose = consulta1.DtConsulta.AddYears(1),
                    IdPet = pet1.IdPet,
                    IdConsulta = consulta1.IdConsulta
                },
                new Vacina
                {
                    NmVacina = "Antirrabica Felina",
                    Fabricante = "MSD Saude Animal",
                    DtAplicacao = consulta2.DtConsulta,
                    DtProximaDose = consulta2.DtConsulta.AddYears(1),
                    IdPet = pet2.IdPet,
                    IdConsulta = consulta2.IdConsulta
                }
            );

           
            db.Medicamentos.AddRange(
                new Medicamento
                {
                    NmMedicamento = "Vermifugo Drontal Plus",
                    Dosagem = "1 comprimido (faixa 20-35 kg)",
                    Frequencia = "A cada 6 meses",
                    DtInicio = consulta1.DtConsulta,
                    DtFim = consulta1.DtConsulta.AddDays(1),
                    IdPet = pet1.IdPet,
                    IdConsulta = consulta1.IdConsulta
                },
                new Medicamento
                {
                    NmMedicamento = "Pomada Dermovet",
                    Dosagem = "Aplicar fina camada na regiao afetada",
                    Frequencia = "2x ao dia (manha e noite)",
                    DtInicio = consulta2.DtConsulta,
                    DtFim = consulta2.DtConsulta.AddDays(14),
                    IdPet = pet2.IdPet,
                    IdConsulta = consulta2.IdConsulta
                }
            );

            db.SaveChanges();
        }
    }
}