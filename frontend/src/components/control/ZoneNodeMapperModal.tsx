import React, { useState, useEffect, useMemo, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polygon, useMapEvents, useMap } from 'react-leaflet';
import L from 'leaflet';
import { ServiceRequest, SensorNode } from '../../types';
import { 
  MapPin, Cpu, Radio, Zap, CheckCircle2, Plus, Info, Layers, 
  RefreshCw, Maximize2, Move, Trash2, Crosshair, Edit3, Save 
} from 'lucide-react';
import { Button } from '../ui/BaseUI';
import { supportService, deviceService } from '../../services';

interface ZoneNodeMapperModalProps {
  isOpen: boolean;
  onClose: () => void;
  request: ServiceRequest;
  onSaveMapping?: (nodes: SensorNode[], mappedCount: number) => Promise<void> | void;
  selectedHardwareItems?: any[];
}

interface UnassignedDevice {
  deviceId: string;
  code: string;
  name: string;
  type: 'GATEWAY' | 'SOIL_SENSOR' | 'AIR_SENSOR' | 'VALVE' | 'PUMP';
  mac: string;
}

// ─── Custom Leaflet Pins ────────────────────────────────────────────────────────

const createCenterPinIcon = () =>
  L.divIcon({
    className: 'custom-center-pin-wrapper',
    html: `
      <div style="
        background-color: #119653;
        width: 26px;
        height: 26px;
        border-radius: 50%;
        border: 3px solid white;
        box-shadow: 0 4px 14px rgba(0,0,0,0.4);
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: grab;
      ">
        <div style="color: white; font-size: 11px; font-weight: 800; font-family: monospace;">C</div>
      </div>
    `,
    iconSize: [26, 26],
    iconAnchor: [13, 13],
  });

const createVertexPinIcon = (index: number) =>
  L.divIcon({
    className: 'custom-vertex-pin-wrapper',
    html: `
      <div style="position: relative; display: flex; align-items: center; justify-content: center; cursor: grab;">
        <div style="
          background-color: #10b981;
          width: 18px;
          height: 18px;
          border-radius: 50%;
          border: 2px solid white;
          box-shadow: 0 2px 8px rgba(0,0,0,0.4);
        "></div>
        <div style="
          position: absolute;
          top: -20px;
          background: #119653;
          color: #ffffff;
          font-size: 10px;
          font-weight: 700;
          font-family: monospace;
          padding: 1px 5px;
          border-radius: 4px;
          border: 1px solid rgba(52, 211, 153, 0.4);
          white-space: nowrap;
          box-shadow: 0 2px 6px rgba(0,0,0,0.3);
        ">#${index + 1}</div>
      </div>
    `,
    iconSize: [20, 20],
    iconAnchor: [10, 10],
  });

const createNodePinIcon = (code: string, isSelected: boolean) => {
  const isGw = code.includes('GW');
  const isActuator = code.includes('VALVE') || code.includes('ACT') || code.includes('PUMP');
  const bg = isGw ? '#f59e0b' : isActuator ? '#0284c7' : isSelected ? '#10b981' : '#059669';

  return L.divIcon({
    className: 'custom-node-pin-wrapper',
    html: `
      <div style="position: relative; display: flex; align-items: center; justify-content: center; cursor: grab;">
        <div style="
          background-color: ${bg};
          width: 24px;
          height: 24px;
          border-radius: ${isGw ? '6px' : '50%'};
          border: 2.5px solid white;
          box-shadow: 0 4px 12px rgba(0,0,0,0.45);
          display: flex;
          align-items: center;
          justify-content: center;
          color: white;
          font-size: 11px;
        ">
          ${isGw ? '📻' : isActuator ? '⚡' : '📡'}
        </div>
        <div style="
          position: absolute;
          top: -22px;
          background: #119653;
          color: #ffffff;
          font-size: 10px;
          font-weight: 700;
          font-family: monospace;
          padding: 1px 6px;
          border-radius: 4px;
          border: 1px solid rgba(52, 211, 153, 0.4);
          white-space: nowrap;
          box-shadow: 0 2px 6px rgba(0,0,0,0.35);
        ">${code}</div>
      </div>
    `,
    iconSize: [24, 24],
    iconAnchor: [12, 12],
  });
};

// Map Controller for click events and auto fit zoom
const MapEventsAndFitter: React.FC<{
  onMapClick: (lat: number, lng: number) => void;
  fitKey: number;
  polygon: [number, number][];
  center: [number, number];
}> = ({ onMapClick, fitKey, polygon, center }) => {
  const map = useMap();

  useMapEvents({
    click(e) {
      onMapClick(parseFloat(e.latlng.lat.toFixed(6)), parseFloat(e.latlng.lng.toFixed(6)));
    },
  });

  useEffect(() => {
    if (fitKey === 0) return;
    if (polygon && polygon.length >= 3) {
      const bounds = L.latLngBounds(polygon);
      map.fitBounds(bounds, { padding: [50, 50] });
    } else {
      map.setView(center, 17);
    }
  }, [fitKey]);

  return null;
};

// Vertex Marker component
const DraggableVertexMarker: React.FC<{
  position: [number, number];
  index: number;
  onDragEnd: (index: number, newLat: number, newLng: number) => void;
}> = ({ position, index, onDragEnd }) => {
  const eventHandlers = useMemo(
    () => ({
      dragend(e: any) {
        const marker = e.target;
        if (marker) {
          const pos = marker.getLatLng();
          onDragEnd(index, parseFloat(pos.lat.toFixed(6)), parseFloat(pos.lng.toFixed(6)));
        }
      },
    }),
    [index, onDragEnd]
  );

  return (
    <Marker
      position={position}
      icon={createVertexPinIcon(index)}
      draggable={true}
      eventHandlers={eventHandlers}
    >
      <Popup>
        <div className="text-xs font-semibold p-1">
          <span className="text-[#119653] font-bold block">Đỉnh ranh giới #{index + 1} của Zone</span>
          <span className="font-mono text-[10px] text-slate-500">[{position[0]}, {position[1]}]</span>
        </div>
      </Popup>
    </Marker>
  );
};

// Node Marker on GIS map
const DraggableNodeMarker: React.FC<{
  node: SensorNode;
  index: number;
  isSelected: boolean;
  onSelect: (node: SensorNode) => void;
  onDragEnd: (nodeId: string, newLat: number, newLng: number) => void;
  onUnmap: (node: SensorNode) => void;
}> = ({ node, index, isSelected, onSelect, onDragEnd, onUnmap }) => {
  const position: [number, number] = [node.latitude, node.longitude];

  const eventHandlers = useMemo(
    () => ({
      click() {
        onSelect(node);
      },
      dragend(e: any) {
        const marker = e.target;
        if (marker) {
          const pos = marker.getLatLng();
          onDragEnd(node.nodeId, parseFloat(pos.lat.toFixed(6)), parseFloat(pos.lng.toFixed(6)));
        }
      },
    }),
    [node, onSelect, onDragEnd]
  );

  return (
    <Marker
      position={position}
      icon={createNodePinIcon(node.nodeCode, isSelected)}
      draggable={true}
      eventHandlers={eventHandlers}
    >
      <Popup>
        <div className="p-1.5 space-y-2 text-slate-800 text-xs min-w-[200px]">
          <div className="flex items-center justify-between border-b border-slate-200 pb-1">
            <span className="font-bold text-[#119653] flex items-center gap-1 font-mono">
              <Cpu size={13} /> #{index + 1} {node.nodeCode}
            </span>
            <span className="text-[10px] bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded font-mono font-bold">
              {node.status}
            </span>
          </div>
          <div className="space-y-1">
            <div className="font-bold text-slate-900 text-xs">{node.name}</div>
            <div className="text-[11px] text-slate-500 font-mono">MAC: {node.serialNumber}</div>
            <div className="text-[11px] text-slate-600 font-mono">
              Tọa độ GIS: [{node.latitude.toFixed(6)}, {node.longitude.toFixed(6)}]
            </div>
          </div>
          <div className="pt-2 border-t border-slate-100 flex items-center justify-between gap-2">
            <span className="text-[10px] text-amber-700 italic flex items-center gap-0.5">
              <Move size={10} /> Kéo ghim để dời vị trí
            </span>
            <button
              type="button"
              onClick={() => onUnmap(node)}
              className="text-[10px] text-rose-600 hover:text-rose-800 font-bold hover:underline flex items-center gap-0.5"
            >
              <Trash2 size={11} /> Gỡ Node
            </button>
          </div>
        </div>
      </Popup>
    </Marker>
  );
};

// Default Contract Items (7 items matching official quotation)
const DEFAULT_CONTRACT_ITEMS = [
  {
    id: 'item-valve-01',
    code: 'ACT-VALVE-01',
    name: 'Node Điều khiển Van Solenoid Tưới nhỏ giọt 4 Cổng',
    unit: 'Bộ',
    unitPrice: 2150000,
    vatPercent: 8,
    quantity: 2,
    totalAmount: 4644000,
    notes: '4 Relay 12V/24V, Hỗ trợ phản hồi trạng thái công tắc',
    isSelected: true,
  },
  {
    id: 'item-gw-01',
    code: 'GW-ESP32-DL01',
    name: 'Trạm Central Gateway ESP32-LoRa Dual Antenna',
    unit: 'Trạm',
    unitPrice: 3800000,
    vatPercent: 8,
    quantity: 1,
    totalAmount: 4104000,
    notes: 'LoRa 915MHz, Chống nước IP67, Bảo hành 24 tháng',
    isSelected: true,
  },
  {
    id: 'item-air-02',
    code: 'SN-AIR-02',
    name: 'Node Cảm biến Vi khí hậu Không khí SHT30',
    unit: 'Node',
    unitPrice: 950000,
    vatPercent: 8,
    quantity: 2,
    totalAmount: 2052000,
    notes: 'Sensirion SHT30, Đo Nhiệt độ, Độ ẩm & CO2',
    isSelected: true,
  },
  {
    id: 'item-soil-01',
    code: 'SN-SOIL-01',
    name: 'Node Cảm biến Độ ẩm & Nhiệt độ Đất RS485 Probe',
    unit: 'Node',
    unitPrice: 1250000,
    vatPercent: 8,
    quantity: 2,
    totalAmount: 2700000,
    notes: 'Đầu đo 3-in-1 (Nhiệt, Ẩm, EC Đất), Giảm 5%',
    isSelected: true,
  },
];

const determineDeviceType = (code?: string, category?: string, name?: string): 'GATEWAY' | 'SOIL_SENSOR' | 'AIR_SENSOR' | 'VALVE' | 'PUMP' => {
  const upper = `${code || ''} ${category || ''} ${name || ''}`.toUpperCase();
  if (upper.includes('GW') || upper.includes('GATEWAY') || upper.includes('TRẠM CENTRAL')) return 'GATEWAY';
  if (upper.includes('VALVE') || upper.includes('VAN') || upper.includes('SOLENOID')) return 'VALVE';
  if (upper.includes('PUMP') || upper.includes('BƠM')) return 'PUMP';
  if (upper.includes('AIR') || upper.includes('KHÔNG KHÍ') || upper.includes('SHT30')) return 'AIR_SENSOR';
  if (upper.includes('SOIL') || upper.includes('ĐẤT') || upper.includes('RS485')) return 'SOIL_SENSOR';
  return 'SOIL_SENSOR';
};

const generateMacAddress = (code: string, index: number = 1): string => {
  const upper = (code || '').toUpperCase();
  if (upper.includes('GW')) return `24:DC:C3:88:00:${String(index).padStart(2, '0')}`;
  if (upper.includes('VALVE')) return `24:DC:C3:44:01:${String(index).padStart(2, '0')}`;
  if (upper.includes('AIR')) return `24:DC:C3:77:02:${String(index).padStart(2, '0')}`;
  if (upper.includes('SOIL')) return `24:DC:C3:66:01:${String(index).padStart(2, '0')}`;
  return `24:DC:C3:11:00:${String(index).padStart(2, '0')}`;
};

const expandContractDevices = (rawItems: any[]): UnassignedDevice[] => {
  const items = Array.isArray(rawItems) && rawItems.length > 0 ? rawItems : DEFAULT_CONTRACT_ITEMS;
  const list: UnassignedDevice[] = [];

  items.forEach((item: any, itemIdx: number) => {
    const qty = typeof item.quantity === 'number' && item.quantity > 0 ? item.quantity : 1;
    const baseCode = item.code || item.hardwareItemCode || `DEV-${itemIdx + 1}`;
    const baseName = item.name || item.hardwareItemName || 'Thiết bị Hợp đồng';
    const type = determineDeviceType(baseCode, item.category, baseName);

    for (let q = 1; q <= qty; q++) {
      const code = qty > 1 ? `${baseCode} #${q}` : baseCode;
      const name = qty > 1 ? `${baseName} (#${q})` : baseName;
      const mac = item.mac || item.macAddress || generateMacAddress(baseCode, q);
      const devId = `contract-node-${item.id || baseCode}-${q}`;

      list.push({
        deviceId: devId,
        code,
        name,
        type,
        mac,
      });
    }
  });

  return list;
};

export const ZoneNodeMapperModal: React.FC<ZoneNodeMapperModalProps> = ({
  isOpen,
  onClose,
  request,
  onSaveMapping,
  selectedHardwareItems,
}) => {
  // Center of Zone
  const [center, setCenter] = useState<[number, number]>([11.9404, 108.4583]);
  const [mapType, setMapType] = useState<'osm' | 'street' | 'satellite'>('osm');
  const [fitKey, setFitKey] = useState(0);
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  // Zone Boundary Polygon Coordinates (Da Lat Greenhouse 01)
  const zonePolygonCoords: [number, number][] = [
    [11.9408, 108.4578],
    [11.9408, 108.4590],
    [11.9400, 108.4590],
    [11.9400, 108.4578],
  ];

  // Existing nodes in this zone / request (with real GIS coordinates)
  const [nodes, setNodes] = useState<SensorNode[]>([]);

  // Unassigned devices ready to be pinned on GIS Map
  const [unassignedDevices, setUnassignedDevices] = useState<UnassignedDevice[]>([]);

  const [selectedDevice, setSelectedDevice] = useState<UnassignedDevice | null>(null);
  const [activePinNode, setActivePinNode] = useState<SensorNode | null>(null);
  const [successToast, setSuccessToast] = useState<string | null>(null);

  // Fetch real mapped devices from backend when modal opens
  useEffect(() => {
    if (!isOpen) return;
    const fetchZoneNodes = async () => {
      try {
        setIsLoading(true);
        const zoneId = request.zoneId || '32000000-0000-0000-0000-000000000001';
        const locs = await supportService.getMappedNodes(zoneId);
        if (Array.isArray(locs) && locs.length > 0) {
          const loadedNodes: SensorNode[] = locs.map((loc: any, idx: number) => {
            const hasLat = typeof loc.latitude === 'number' && loc.latitude > 0;
            const hasLng = typeof loc.longitude === 'number' && loc.longitude > 0;
            return {
              nodeId: loc.deviceId || `loaded-node-${idx}-${Date.now()}`,
              farmId: request.farmId || '30000000-0000-0000-0000-000000000001',
              zoneId: zoneId,
              zoneName: request.zoneName || 'Nhà màng Z01',
              name: `${loc.deviceType === 'ActuatorNode' ? 'Cụm Van/Bơm' : 'Node Cảm biến'} - ${loc.hardwareAddress}`,
              nodeCode: loc.hardwareAddress || `NODE-0${idx + 1}`,
              serialNumber: loc.hardwareAddress,
              latitude: hasLat ? loc.latitude : 11.9403 + (idx * 0.0003),
              longitude: hasLng ? loc.longitude : 108.4581 + (idx * 0.0004),
              status: (loc.status?.toUpperCase() || 'ONLINE') as any,
              firmwareVersion: 'v2.4.1',
              batteryLevel: loc.batteryLevel ?? 95,
              rssi: loc.rssi ?? -70,
              lastSeenAt: 'Trực tuyến',
              sensorsCount: loc.deviceType === 'SensorNode' ? 2 : 0,
              actuatorsCount: loc.deviceType === 'ActuatorNode' ? 1 : 0,
            };
          });
          setNodes(loadedNodes);
        } else {
          setNodes([]);
        }

        // Fetch spare parts to populate unassigned list
        const spareParts = await supportService.getTechnicianSpareParts().catch(() => []);
        if (Array.isArray(spareParts) && spareParts.length > 0) {
          const unassigned: UnassignedDevice[] = spareParts.map((sp: any, idx: number) => ({
            deviceId: sp.id || `spare-${idx}-${Date.now()}`,
            code: sp.code || `SP-${idx + 1}`,
            name: sp.name || 'Vật tư dự phòng',
            type: (sp.category === 'VALVE' || sp.category === 'PUMP' ? 'VALVE' : sp.category === 'GATEWAY' ? 'GATEWAY' : 'SOIL_SENSOR'),
            mac: sp.macAddress || sp.serialNumber || `24:DC:C3:00:11:${String(idx).padStart(2, '0')}`,
          }));
          setUnassignedDevices(unassigned);
          setSelectedDevice(unassigned[0] || null);
        } else {
          // Fallback dummy items with unique IDs so technician can always test placing nodes
          const fallbackItems: UnassignedDevice[] = [
            { deviceId: `unassigned-gw-${Date.now()}-1`, code: 'GW-ESP32-NEW', name: 'Gateway LoRa Central ESP32-S3', type: 'GATEWAY', mac: '24:DC:C3:88:99:A1' },
            { deviceId: `unassigned-sensor-${Date.now()}-2`, code: 'SN-NPK-EC-03', name: 'Node Cảm biến NPK & Độ dẫn điện EC', type: 'SOIL_SENSOR', mac: '24:DC:C3:11:22:33' },
            { deviceId: `unassigned-actuator-${Date.now()}-3`, code: 'ACT-VALVE-V2', name: 'Node Cụm Van Điện từ Phun sương V2', type: 'VALVE', mac: '24:DC:C3:44:55:66' },
          ];
          setUnassignedDevices(fallbackItems);
          setSelectedDevice(fallbackItems[0]);
        }
      } catch (err) {
        console.error('Error fetching zone mapped nodes:', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchZoneNodes();
  }, [isOpen, request.zoneId]);

  // Existing nodes in this zone (with real GIS coordinates)
  const [nodes, setNodes] = useState<SensorNode[]>([]);

  const getTileConfig = () => {
    switch (mapType) {
      case 'satellite':
        return {
          url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          attribution: 'Tiles &copy; Esri &mdash; High-Resolution Farm Satellite',
        };
      case 'street':
        return {
          url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          attribution: 'Tiles &copy; Esri World Street Map',
        };
      case 'osm':
      default:
        return {
          url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          attribution: '&copy; OpenStreetMap contributors',
        };
    }
  };

  const currentTile = getTileConfig();

  // Area calculation
  const areaM2 = calculatePolygonAreaM2(zonePolygon);
  const areaHa = (areaM2 / 10000).toFixed(2);

  // Center pin drag handler
  const centerEventHandlers = useMemo(
    () => ({
      dragend(e: any) {
        const marker = e.target;
        if (marker) {
          const pos = marker.getLatLng();
          const newCenter: [number, number] = [parseFloat(pos.lat.toFixed(6)), parseFloat(pos.lng.toFixed(6))];
          if (zonePolygon.length > 0) {
            const deltaLat = newCenter[0] - center[0];
            const deltaLng = newCenter[1] - center[1];
            setZonePolygon(prev =>
              prev.map(p => [
                parseFloat((p[0] + deltaLat).toFixed(6)),
                parseFloat((p[1] + deltaLng).toFixed(6)),
              ])
            );
          }
          setCenter(newCenter);
        }
      },
    }),
    [center, zonePolygon]
  );

  // Dragging vertex points #1, #2, #3, #4 of Zone
  const handleDragVertex = (idx: number, newLat: number, newLng: number) => {
    setZonePolygon(prev => {
      const next = [...prev];
      next[idx] = [newLat, newLng];
      return next;
    });
  };

  // Click on map to place selected Node into Zone
  const handleMapClick = (lat: number, lng: number) => {
    if (!selectedDevice) {
      if (unassignedDevices.length > 0) {
        setSelectedDevice(unassignedDevices[0]);
      } else {
        alert('Tất cả thiết bị theo hợp đồng đã được định vị xong. Bạn có thể kéo thả ghim Node trên bản đồ để chỉnh vị trí.');
      }
      return;
    }

    const newNode: SensorNode = {
      nodeId: selectedDevice.deviceId || `mapped-node-${Date.now()}`,
      farmId: request.farmId || '30000000-0000-0000-0000-000000000001',
      zoneId: request.zoneId || '32000000-0000-0000-0000-000000000001',
      zoneName: request.zoneName || 'Nhà màng Z01',
      name: selectedDevice.name,
      nodeCode: selectedDevice.code,
      serialNumber: selectedDevice.mac,
      latitude: lat,
      longitude: lng,
      status: 'ONLINE',
      firmwareVersion: 'v3.0.0-PROV',
      // Pin và tín hiệu chỉ có khi thiết bị báo về; không điền số giả.
      lastSeenAt: 'Vừa chấm vị trí',
      sensorsCount: selectedDevice.type.includes('SENSOR') ? 2 : 0,
      actuatorsCount: selectedDevice.type === 'VALVE' || selectedDevice.type === 'PUMP' ? 1 : 0,
    };

    setNodes(prev => [...prev, newNode]);
    const updatedUnassigned = unassignedDevices.filter(d => d.deviceId !== selectedDevice.deviceId);
    setUnassignedDevices(updatedUnassigned);
    setSelectedDevice(updatedUnassigned[0] || null);

    setSuccessToast(`Đã chấm Node [${newNode.name}] vào Phân khu (Zone) tại tọa độ (${lat}, ${lng})!`);
    setTimeout(() => setSuccessToast(null), 3000);
  };

  const handleDragNodeEnd = (nodeId: string, newLat: number, newLng: number) => {
    setNodes(prev =>
      prev.map(n => (n.nodeId === nodeId ? { ...n, latitude: newLat, longitude: newLng } : n))
    );
    if (activePinNode && activePinNode.nodeId === nodeId) {
      setActivePinNode(prev => prev ? { ...prev, latitude: newLat, longitude: newLng } : null);
    }
    setSuccessToast(`Đã dịch chuyển Node đến tọa độ mới: (${newLat}, ${newLng})`);
    setTimeout(() => setSuccessToast(null), 2500);
  };

  const handleUnmapNode = (targetNode: SensorNode) => {
    setNodes(prev => prev.filter(n => n.nodeId !== targetNode.nodeId));
    setUnassignedDevices(prev => [
      ...prev,
      {
        deviceId: targetNode.nodeId,
        code: targetNode.nodeCode,
        name: targetNode.name,
        type: determineDeviceType(targetNode.nodeCode, undefined, targetNode.name),
        mac: targetNode.serialNumber,
      },
    ]);
    if (activePinNode?.nodeId === targetNode.nodeId) {
      setActivePinNode(null);
    }
    setSuccessToast(`Đã gỡ Node [${targetNode.nodeCode}] khỏi sơ đồ.`);
    setTimeout(() => setSuccessToast(null), 2500);
  };

  const handleSave = async () => {
    try {
      setIsSaving(true);
      if (onSaveMapping) {
        await onSaveMapping(nodes, nodes.length);
      }
      onClose();
    } catch (err: any) {
      console.error('Error saving mapping:', err);
      alert('Lỗi lưu sơ đồ GIS: ' + (err?.response?.data?.message || err?.message || 'Vui lòng thử lại.'));
    } finally {
      setIsSaving(false);
    }
  };

  if (!isOpen) return null;

  const isMaintenance = request.requestType === 'MAINTENANCE' || request.requestType === 'REPAIR' || request.requestType === 'REPLACEMENT';
  const zoneDisplayName = request.zoneName || currentZoneData?.name || 'Nhà màng Z01';

  return (
    <div className={`fixed inset-0 z-50 flex items-center justify-center p-3 bg-slate-950/75 backdrop-blur-sm animate-in fade-in duration-200 ${isFullscreen ? 'p-0' : ''}`}>
      <div className={`w-full ${isFullscreen ? 'h-full max-w-none rounded-none' : 'max-w-6xl rounded-2xl max-h-[95vh]'} bg-white border border-slate-200 shadow-2xl overflow-hidden flex flex-col`}>
        {/* Header */}
        <div className="p-4 bg-gradient-to-r from-[#119653] via-emerald-600 to-emerald-500 text-white flex items-center justify-between shrink-0 border-b border-emerald-400/40">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-emerald-800/30 border border-emerald-300/40 rounded-xl text-white backdrop-blur-xs">
              <MapPin size={22} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                  isMaintenance ? 'bg-amber-400/30 text-amber-100 border border-amber-300/40' : 'bg-emerald-800/30 text-emerald-100 border border-emerald-300/40'
                }`}>
                  {isMaintenance ? 'BẢO TRÌ & THAY THẾ NODE' : 'LẮP ĐẶT MỚI & CHẤM VỊ TRÍ GIS'}
                </span>
                <span className="text-xs text-emerald-100 font-mono">Request #{request.serviceRequestId}</span>
              </div>
              <h2 className="text-base font-bold text-white mt-0.5">
                Chấm Node & Sửa Biểu đồ GIS Phân khu: <span className="text-emerald-300">{request.zoneName || 'Nhà màng Z01'}</span>
              </h2>
              <p className="text-[11px] text-emerald-100/90 mt-0.5">
                Nông trại: <strong>{request.farmName}</strong> • Ranh giới GIS Phân khu (Zone) màu xanh lá. Chấm thiết bị vào đúng ranh giới của Zone.
              </p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 text-white/80 hover:text-white rounded-lg hover:bg-emerald-800/50 transition-colors">
            ✕
          </button>
        </div>

        {/* Success Toast */}
        {successToast && (
          <div className="p-2.5 bg-emerald-600 text-white text-xs font-bold text-center flex items-center justify-center gap-2 animate-in fade-in shrink-0">
            <CheckCircle2 size={16} /> {successToast}
          </div>
        )}

        {/* Content Body */}
        <div className="grid grid-cols-1 lg:grid-cols-4 flex-1 overflow-hidden">
          {/* Left Panel: Unassigned Equipment List */}
          <div className="lg:col-span-1 p-4 bg-slate-50 border-r border-slate-200 overflow-y-auto space-y-4">
            <div>
              <h3 className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                <Cpu size={14} className="text-[#119653]" /> Thiết bị Chờ Chấm Node ({unassignedDevices.length})
              </h3>
              <p className="text-[11px] text-slate-500 mt-1">
                Chọn thiết bị bên dưới, sau đó nhấp vào vị trí bất kỳ trên bản đồ GIS để định vị Node.
              </p>
            </div>

            {unassignedDevices.length === 0 ? (
              <div className="p-4 text-center bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-900 text-xs">
                <CheckCircle2 size={24} className="mx-auto text-emerald-600 mb-1" />
                <span className="font-bold">Đã chấm hết thiết bị!</span>
                <p className="text-[11px] text-emerald-700 mt-1">Tất cả vật tư đã được chuyển đổi thành các Node định vị trên bản đồ GIS.</p>
              </div>

              {/* Status Banner when all nodes are mapped */}
              {unassignedDevices.length === 0 ? (
                <div className="p-4 bg-gradient-to-br from-emerald-50 to-teal-50 border border-emerald-200 rounded-2xl shadow-xs text-center space-y-2">
                  <div className="w-10 h-10 mx-auto rounded-full bg-emerald-500/20 text-emerald-600 flex items-center justify-center">
                    <Sparkles size={20} />
                  </div>
                  <h4 className="font-bold text-emerald-950 text-xs">🎉 Đã chấm hết tất cả {nodes.length} Node!</h4>
                  <p className="text-[11px] text-emerald-800 leading-relaxed">
                    Tất cả vật tư theo Hợp đồng đã được định vị chính xác bên trong ranh giới Phân khu (Zone). Bạn có thể kéo thả ghim Node để tinh chỉnh tọa độ GPS.
                  </p>
                </div>
              ) : (
                <div className="space-y-2">
                  <p className="text-[11px] text-slate-500">
                    Chọn thiết bị bên dưới, sau đó nhấp vào vị trí bất kỳ bên trong Zone (đa giác xanh) trên bản đồ để định vị Node.
                  </p>
                  {unassignedDevices.map(dev => {
                    const isSelected = selectedDevice?.deviceId === dev.deviceId;
                    return (
                      <div
                        key={dev.deviceId}
                        onClick={() => setSelectedDevice(dev)}
                        className={`p-3 rounded-xl border text-xs cursor-pointer transition-all ${
                          isSelected
                            ? 'bg-emerald-700 text-white border-emerald-700 shadow-md ring-2 ring-emerald-400'
                            : 'bg-white border-slate-200 text-slate-800 hover:border-emerald-500 hover:shadow-xs'
                        }`}
                      >
                        <div className="flex items-center justify-between">
                          <span className={`font-mono font-bold text-[10px] px-1.5 py-0.5 rounded ${
                            isSelected ? 'bg-emerald-800 text-emerald-100 border border-emerald-600' : 'bg-slate-100 text-slate-700 border border-slate-200'
                          }`}>
                            {dev.code}
                          </span>
                          {isSelected && <span className="text-[10px] bg-emerald-500 text-white px-2 py-0.5 rounded font-bold animate-pulse">ĐANG CHỌN</span>}
                        </div>
                        <h4 className="font-bold text-xs mt-1.5 leading-snug">{dev.name}</h4>
                        <p className={`text-[10px] font-mono mt-1 ${isSelected ? 'text-emerald-200' : 'text-slate-500'}`}>
                          MAC: {dev.mac}
                        </p>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* List of currently placed nodes in Zone */}
              <div className="pt-2 border-t border-slate-200">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-[11px] font-bold text-slate-700 uppercase tracking-wider">
                    Node Đã Định Vị ({nodes.length})
                  </span>
                  {nodes.length > 0 && (
                    <span className="text-[10px] text-emerald-600 font-bold flex items-center gap-1">
                      <Check size={11} /> Đã ghim trên Map
                    </span>
                  )}
                </div>

                <div className="space-y-1.5 max-h-[220px] overflow-y-auto pr-1">
                  {nodes.map((n, i) => (
                    <div
                      key={dev.deviceId}
                      onClick={() => setSelectedDevice(dev)}
                      className={`p-3 rounded-xl border text-xs cursor-pointer transition-all ${
                        isSelected
                          ? 'bg-emerald-700 text-white border-emerald-700 shadow-md ring-2 ring-emerald-400'
                          : 'bg-white border-slate-200 text-slate-800 hover:border-emerald-500'
                      }`}
                    >
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-emerald-500 shrink-0" />
                          <span className="font-bold text-slate-900 truncate font-mono text-[11px]">{n.nodeCode}</span>
                        </div>
                        <p className="text-[10px] text-slate-500 truncate mt-0.5">{n.name}</p>
                      </div>
                      <h4 className="font-bold text-xs mt-1.5">{dev.name}</h4>
                      <p className={`text-[10px] font-mono mt-1 ${isSelected ? 'text-slate-300' : 'text-slate-500'}`}>
                        MAC: {dev.mac}
                      </p>
                      {isSelected && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            if (navigator.geolocation) {
                              navigator.geolocation.getCurrentPosition(
                                (pos) => {
                                  const lat = parseFloat(pos.coords.latitude.toFixed(6));
                                  const lng = parseFloat(pos.coords.longitude.toFixed(6));
                                  handleMapClick(lat, lng);
                                },
                                () => {
                                  const simLat = 11.9400 + Math.random() * 0.0008;
                                  const simLng = 108.4578 + Math.random() * 0.0012;
                                  handleMapClick(parseFloat(simLat.toFixed(6)), parseFloat(simLng.toFixed(6)));
                                }
                              );
                            } else {
                              const simLat = 11.9400 + Math.random() * 0.0008;
                              const simLng = 108.4578 + Math.random() * 0.0012;
                              handleMapClick(parseFloat(simLat.toFixed(6)), parseFloat(simLng.toFixed(6)));
                            }
                          }}
                          className="mt-2 w-full py-1.5 bg-emerald-500 hover:bg-emerald-400 text-white font-bold rounded-lg text-[10px] flex items-center justify-center gap-1 transition-colors"
                        >
                          <Crosshair size={12} /> Lấy GPS điện thoại để chấm Node
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Instruction Tip */}
            <div className="mt-4 p-3 bg-emerald-50/80 border border-emerald-200 rounded-xl text-[11px] text-emerald-950 space-y-1">
              <strong className="flex items-center gap-1 text-emerald-800">
                <Info size={13} /> Thao tác Sửa Biểu đồ GIS:
              </strong>
              <p className="text-emerald-800/90 leading-relaxed">
                1. <strong>Thêm Node mới:</strong> Chọn vật tư bên trái rồi bấm lên bản đồ.<br />
                2. <strong>Di chuyển Node:</strong> Kéo thả trực tiếp ghim trên bản đồ.<br />
                3. <strong>Sửa tọa độ:</strong> Nhấp vào Node để sửa trực tiếp vĩ độ/kinh độ hoặc bấm "Lấy GPS thực địa".<br />
                4. Bấm <strong>"Lưu Sơ đồ GIS"</strong> để đồng bộ xuống backend.
              </p>
            </div>
          </div>

          {/* Center Main: Interactive Leaflet GIS Map Canvas */}
          <div className="lg:col-span-3 p-4 bg-slate-100 flex flex-col justify-between overflow-y-auto">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-slate-800 flex items-center gap-1">
                  <Layers size={15} className="text-[#119653]" /> Bản đồ GIS Định vị Phân khu (Interactive Leaflet Map)
                </span>
                <span className="text-[11px] px-2 py-0.5 rounded bg-emerald-100 text-emerald-900 font-mono font-bold border border-emerald-300">
                  {nodes.length} Node Đã Định Vị
                </span>
              </div>
              <span className="text-[11px] text-slate-500 italic">
                {selectedDevice ? `👉 Đang chọn [${selectedDevice.code}]. Nhấp lên bản đồ để chấm Node!` : 'Kéo thả ghim để di chuyển hoặc nhấp chọn để sửa tọa độ'}
              </span>
            </div>

            {/* Canvas Interactive Container */}
            <div className="relative w-full h-[380px] rounded-2xl border border-slate-300 overflow-hidden shadow-inner select-none">
              {/* Map Controls Overlay */}
              <div className="absolute top-3 right-3 z-[1000] flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setFitKey(k => k + 1)}
                  title="Căn vừa ranh giới Node (Fit Zoom)"
                  className="bg-white/95 hover:bg-slate-100 text-slate-800 px-2.5 py-1 rounded-lg border border-slate-200 shadow-md text-xs font-semibold flex items-center gap-1 transition-all cursor-pointer"
                >
                  <Maximize2 size={13} className="text-emerald-600" />
                  <span>Căn Zoom</span>
                </button>

                <div className="bg-white/95 backdrop-blur-md p-1 rounded-lg border border-slate-200 text-xs flex items-center gap-1 shadow-md">
                  <button
                    type="button"
                    onClick={() => setMapType('osm')}
                    className={`px-2 py-1 rounded transition-colors ${mapType === 'osm' ? 'bg-[#119653] text-white font-semibold' : 'text-slate-700 hover:bg-slate-100'}`}
                  >
                    OSM
                  </button>
                  <button
                    type="button"
                    onClick={() => setMapType('street')}
                    className={`px-2 py-1 rounded transition-colors ${mapType === 'street' ? 'bg-[#119653] text-white font-semibold' : 'text-slate-700 hover:bg-slate-100'}`}
                  >
                    Đường phố
                  </button>
                  <button
                    type="button"
                    onClick={() => setMapType('satellite')}
                    className={`px-2 py-1 rounded transition-colors ${mapType === 'satellite' ? 'bg-[#119653] text-white font-semibold' : 'text-slate-700 hover:bg-slate-100'}`}
                  >
                    Vệ tinh
                  </button>
                </div>
              </div>

              {/* Legend Overlay */}
              <div className="absolute bottom-3 left-3 z-[1000] bg-white/90 backdrop-blur-md px-3 py-1.5 rounded-lg border border-slate-200 text-[10px] text-slate-700 shadow-xs flex items-center gap-3">
                <div className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-emerald-500" /> Node Cảm biến</div>
                <div className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded bg-amber-500" /> Gateway</div>
                <div className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded bg-sky-500/30 border border-sky-600 border-dashed" /> Ranh giới Nhà màng</div>
              </div>

              {/* Leaflet GIS Map */}
              <MapContainer
                center={center}
                zoom={17}
                scrollWheelZoom={true}
                zoomControl={true}
                style={{ height: '100%', width: '100%' }}
              >
                <TileLayer
                  key={mapType}
                  attribution={currentTile.attribution}
                  url={currentTile.url}
                  maxZoom={19}
                />

                <MapEventsAndFitter
                  onMapClick={handleMapClick}
                  fitKey={fitKey}
                  nodes={nodes}
                  center={center}
                />

                {/* Zone Boundary Polygon */}
                <Polygon
                  positions={zonePolygonCoords}
                  pathOptions={{ color: '#0284c7', fillColor: '#0284c7', fillOpacity: 0.15, weight: 2, dashArray: '4, 4' }}
                />

                {/* Placed Nodes Markers (Draggable & Clickable) */}
                {nodes.map((node, index) => (
                  <DraggableNodeMarker
                    key={node.nodeId}
                    node={node}
                    index={index}
                    isSelected={activePinNode?.nodeId === node.nodeId}
                    onSelect={setActivePinNode}
                    onDragEnd={handleDragNodeEnd}
                    onUnmap={handleUnmapNode}
                  />
                ))}
              </MapContainer>
            </div>

            {/* Selected Node Details & Manual GIS Coordinate Editor */}
            {activePinNode ? (
              <div className="mt-3 p-3 bg-white border border-slate-200 rounded-xl shadow-xs text-xs space-y-2 animate-in fade-in">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-2">
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-slate-900">{activePinNode.name}</span>
                    <span className="px-2 py-0.5 rounded bg-emerald-100 text-emerald-900 font-mono text-[10px] font-bold">
                      {activePinNode.nodeCode}
                    </span>
                    <span className="text-[11px] text-slate-500 font-mono">
                      MAC: {activePinNode.serialNumber} • Pin: {activePinNode.batteryLevel}% • RSSI: {activePinNode.rssi}dBm
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => handleUnmapNode(activePinNode)}
                      className="text-xs text-rose-600 hover:text-rose-800 font-bold hover:underline px-2 py-1 flex items-center gap-1"
                    >
                      <Trash2 size={12} /> Gỡ Node
                    </button>
                    <Button size="sm" variant="outline" onClick={() => setActivePinNode(null)}>
                      Đóng
                    </Button>
                  </div>
                </div>

                {/* Edit GIS Coordinates Inputs */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 items-center bg-slate-50 p-2.5 rounded-lg border border-slate-200">
                  <div>
                    <label className="text-[10px] font-semibold text-slate-600 block">Vĩ độ (Latitude):</label>
                    <input
                      type="number"
                      step="0.000001"
                      value={activePinNode.latitude}
                      onChange={(e) => {
                        const val = parseFloat(e.target.value);
                        if (!isNaN(val)) {
                          handleDragNodeEnd(activePinNode.nodeId, val, activePinNode.longitude);
                        }
                      }}
                      className="w-full bg-white border border-slate-300 rounded px-2 py-1 font-mono text-xs text-slate-900 focus:outline-none focus:border-emerald-500"
                    />
                  </div>
                  <div>
                    <label className="text-[10px] font-semibold text-slate-600 block">Kinh độ (Longitude):</label>
                    <input
                      type="number"
                      step="0.000001"
                      value={activePinNode.longitude}
                      onChange={(e) => {
                        const val = parseFloat(e.target.value);
                        if (!isNaN(val)) {
                          handleDragNodeEnd(activePinNode.nodeId, activePinNode.latitude, val);
                        }
                      }}
                      className="w-full bg-white border border-slate-300 rounded px-2 py-1 font-mono text-xs text-slate-900 focus:outline-none focus:border-emerald-500"
                    />
                  </div>
                  <div className="flex items-end">
                    <button
                      type="button"
                      onClick={() => {
                        if (navigator.geolocation) {
                          navigator.geolocation.getCurrentPosition(
                            (pos) => {
                              const lat = parseFloat(pos.coords.latitude.toFixed(6));
                              const lng = parseFloat(pos.coords.longitude.toFixed(6));
                              handleDragNodeEnd(activePinNode.nodeId, lat, lng);
                            },
                            () => {
                              const simLat = parseFloat((11.9404 + (Math.random() - 0.5) * 0.0006).toFixed(6));
                              const simLng = parseFloat((108.4583 + (Math.random() - 0.5) * 0.0008).toFixed(6));
                              handleDragNodeEnd(activePinNode.nodeId, simLat, simLng);
                            }
                          );
                        }
                      }}
                      className="w-full py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded text-xs font-semibold flex items-center justify-center gap-1 shadow-xs transition-colors"
                    >
                      <Crosshair size={13} /> Cập nhật GPS Hiện trường
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="mt-3 p-2.5 bg-white border border-dashed border-slate-300 rounded-xl text-center text-xs text-slate-500">
                💡 <span className="font-semibold text-slate-700">Mẹo điều chỉnh:</span> Bạn có thể nhấp chọn bất kỳ ghim Node nào trên bản đồ để sửa tọa độ GPS chính xác hoặc kéo thả trực tiếp.
              </div>
            )}
          </div>
        </div>

        {/* Footer Actions */}
        <div className="p-4 bg-slate-900 border-t border-slate-800 text-white flex flex-col sm:flex-row sm:items-center justify-between gap-3 shrink-0">
          <div className="text-xs text-slate-300">
            Tổng số Node định vị trong Phân khu: <strong className="text-emerald-400 font-mono text-sm">{nodes.length} Nodes</strong>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="ghost" onClick={onClose} className="text-slate-300 hover:text-white">
              Hủy
            </Button>
            <Button 
              onClick={handleSave} 
              disabled={isSaving}
              className="bg-emerald-500 hover:bg-emerald-600 text-slate-950 font-bold shadow-md"
            >
              {isSaving ? (
                <>
                  <RefreshCw size={16} className="mr-1.5 animate-spin" /> Đang lưu sơ đồ GIS...
                </>
              ) : (
                <>
                  <CheckCircle2 size={16} className="mr-1.5" /> Lưu Sơ đồ GIS & Đồng bộ Backend
                </>
              )}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
};
