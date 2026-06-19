namespace Backend.Models
{
    public class ColData
    {
        public int Id { get; set; }
        public string SiloId { get; set; } = string.Empty;
        public DateTime RecordDate { get; set; }
        public double WeightKg { get; set; }
    }
}
