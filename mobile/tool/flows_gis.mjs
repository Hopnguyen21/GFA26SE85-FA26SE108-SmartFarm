const hscroll = { fn: async ({ send, sleep }) => { for (let i = 0; i < 4; i++) { await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 215, y: 108, deltaX: 400, deltaY: 0 }); await sleep(400); } await sleep(800); } };
export const flows = [{ name: 'gis', steps: [
  { do: [{ v: [215, 1050] }, { v: [590, 1100], text: 'owner@smartfarm.demo' }, { v: [590, 1338], text: 'Demo@12345' }, { v: [590, 1676] }, { wait: 12000 }] },
  { do: [hscroll, { click: 'Zone Mới' }, { wait: 6000 }, { scroll: 700 }, { wait: 6000 }], file: 'V2_picker.png' },
] }];
