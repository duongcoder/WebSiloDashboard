namespace Backend.Models
{
    public class Indicator
    {
        public string IndicatorId { get; set; }   // Khóa chính
        public string Name { get; set; }          // Tên hiển thị
        public string Port { get; set; }          // COM port
        public int BaudRate { get; set; }         // Tốc độ truyền
    }
}
