const U = 'owner@smartfarm.demo', P = 'Demo@12345';
const toLogin = [{ v: [215, 1050] }];
const typeCred = (u, p) => [{ v: [590, 1100], text: u }, { v: [590, 1338], text: p }];
const login = [...toLogin, ...typeCred(U, P), { v: [590, 1676] }, { wait: 6000 }];
const toPumpZone = [{ click: 'Đổi / Lọc' }, { wait: 1200 }, { click: 'Đổi Farm' }, { wait: 1200 }, { click: 'Đà Lạt Eco' }, { wait: 2500 }, { click: 'Phân Khu 1' }, { wait: 2500 }, { click: 'Mở chi tiết Zone' }, { wait: 3000 }, { click: 'Thiết bị' }, { wait: 2500 }];
export const flows = [
  { name: 'p2', steps: [{ do: login },
    { do: toPumpZone, file: 'M5_ready.png' },
    { do: [{ v: [1025, 1518] }, { wait: 1500 }, { dump: 1 }], file: 'M6_dialog.png' },
    { do: [{ click: 'Xác nhận BẬT RƠ-LE' }, { wait: 2500 }, { dump: 1 }], file: 'M7_after_confirm.png' },
  ] },
];
