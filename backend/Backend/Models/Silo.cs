using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Backend.Models
{
    public class Silo
    {
        [Key]
        [Column(TypeName = "nvarchar(50)")]
        public string Id { get; set; } = string.Empty;

        public double Weight { get; set; }
        public double Level { get; set; }
    }
}
