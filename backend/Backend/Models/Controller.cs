using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Backend.Models
{
    public class Controller
    {
        [Key]
        [Column(TypeName = "nvarchar(100)")]
        public string ControllerId { get; set; } = string.Empty;

        // Alias cho UI: trả về thêm field "id" = controllerId
        public string Id => ControllerId;

        public string Ip { get; set; } = string.Empty;

        public int Port { get; set; }

        [Column(TypeName = "nvarchar(100)")]
        public string SerialNumber { get; set; } = string.Empty;
    }
}
