# Sistema de Navegação Indoor

## 📋 Arquitetura

O sistema de navegação foi desenhado de forma **modular** para facilitar manutenção e compreensão.

### Estrutura de Pastas

```
features/navigation/
├── data/
│   └── models/
│       └── navigation_instruction.dart  # Modelo de instruções (virar esquerda/direita)
│
├── domain/
│   ├── navigation_controller.dart       # Controlador principal (gerencia estado)
│   └── route_tracker.dart               # Rastreador de posição na rota
│
└── presentation/
    ├── navigation_page.dart             # Página de navegação normal (azul)
    ├── emergency_navigation_page.dart   # Página de navegação emergência (vermelho)
    └── widgets/
        ├── navigation_header.dart       # Widget topo (próxima curva)
        └── navigation_bottom_sheet.dart # Widget bottom (info + End Route)
```

---

## 🧩 Componentes

### 1. **Data Layer** (Modelos)

#### `NavigationInstruction`
- Representa uma instrução de navegação
- **Propriedades:** `type`, `distanceToNextTurn`, `nodeId`
- **Métodos:** `getDescription()`, `formattedDistance`

### 2. **Domain Layer** (Lógica)

#### `RouteTracker`
- Rastreia posição na rota
- Calcula próxima instrução
- Detecta chegada ao destino

#### `NavigationController`
- Gerencia estado completo
- Notifica mudanças (ChangeNotifier)
- Simula movimento (testes)

### 3. **Presentation Layer** (UI)

#### `NavigationPage` - Modo Normal
#### `EmergencyNavigationPage` - Modo Emergência
#### `NavigationHeader` - Instrução no topo
#### `NavigationBottomSheet` - Info expansível

---

## 🚀 Como Usar

### Iniciar Navegação Normal
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => NavigationPage(
    route: routeFromAPI,
    destination: poiDestination,
    nodes: allNodes,
  ),
));
```

### Navegação Emergência
Automática ao clicar botão emergência → encontra saída mais próxima → inicia navegação

---

## 🎯 Framework Escolhido

**Custom Flutter UI** (sem packages externos)

**Razões:**
- PNG estático (não precisa tiles)
- Controlo total da UI
- Zero overhead
- Modularidade máxima

---

## 📍 Algoritmo de Curvas

Calcula ângulo entre 3 waypoints:
- `< 30°` → continuar reto
- `> 0°` → virar esquerda
- `< 0°` → virar direita

---

## 🌍 Traduções

Português + Inglês em `lib/l10n/app_*.arb`
