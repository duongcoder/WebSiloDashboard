using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace Backend.Hubs
{
    public class SiloHub : Hub
    {
        // Gửi dữ liệu silo mới cho tất cả client
        public async Task SendSilosUpdate(object silos, object scaleValue)
        {
            await Clients.All.SendAsync("UpdateSilos", silos);
        }

        public async Task SendScaleValue(object scaleValue)
        {
            await Clients.All.SendAsync("ReceiveScaleValue", scaleValue);
        }
    }
}
