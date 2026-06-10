using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace Backend.Hubs
{
    public class SiloHub : Hub
    {
        // Gửi dữ liệu silo mới cho tất cả client
        public async Task SendSilosUpdate(object silos)
        {
            await Clients.All.SendAsync("UpdateSilos", silos);
        }
    }
}
