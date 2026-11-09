import React, { useState, useMemo, useCallback, useRef, useEffect } from 'react';
import { ChevronUp, ChevronDown, Search, Filter, Download, Settings, Moon, Sun, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, X, Check, MoreVertical, Columns, RefreshCw } from 'lucide-react';

// ============================================================================
// Types
// ============================================================================

const generateId = () => Math.random().toString(36).substr(2, 9);

// ============================================================================
// DonnÃ©es de dÃ©monstration - Plan Comptable OHADA
// ============================================================================

const generateEcritures = (count) => {
  const journaux = ['VT', 'AC', 'BQ', 'CA', 'OD'];
  const statuts = ['brouillon', 'validee', 'lettree', 'annulee'];
  const comptes = [
    { numero: '411100', libelle: 'Clients locaux' },
    { numero: '401100', libelle: 'Fournisseurs locaux' },
    { numero: '521100', libelle: 'Banque SGBG' },
    { numero: '571000', libelle: 'Caisse siÃ¨ge' },
    { numero: '601100', libelle: 'Achats de marchandises' },
    { numero: '701100', libelle: 'Ventes de marchandises' },
    { numero: '445200', libelle: 'TVA rÃ©cupÃ©rable' },
    { numero: '443000', libelle: 'TVA facturÃ©e' },
    { numero: '661000', libelle: 'RÃ©munÃ©rations personnel' },
    { numero: '431000', libelle: 'SÃ©curitÃ© sociale' },
  ];
  const utilisateurs = ['Jean MBARGA', 'Marie NKOLO', 'Pierre ESSOMBA', 'Admin'];

  return Array.from({ length: count }, (_, i) => {
    const compte = comptes[Math.floor(Math.random() * comptes.length)];
    const isDebit = Math.random() > 0.5;
    const montant = Math.floor(Math.random() * 10000000) + 50000;
    const jour = Math.floor(Math.random() * 28) + 1;
    
    return {
      id: `ECR-${String(i + 1).padStart(6, '0')}`,
      date: `2026-01-${String(jour).padStart(2, '0')}`,
      journal: journaux[Math.floor(Math.random() * journaux.length)],
      piece: `${journaux[Math.floor(Math.random() * journaux.length)]}-${String(Math.floor(Math.random() * 999) + 1).padStart(4, '0')}`,
      compte: compte.numero,
      libelleCompte: compte.libelle,
      libelle: `OpÃ©ration ${i + 1} - ${compte.libelle}`,
      debit: isDebit ? montant : 0,
      credit: isDebit ? 0 : montant,
      statut: statuts[Math.floor(Math.random() * statuts.length)],
      utilisateur: utilisateurs[Math.floor(Math.random() * utilisateurs.length)],
    };
  });
};

// ============================================================================
// Composants UI de base
// ============================================================================

const Badge = ({ variant, children }) => {
  const variants = {
    brouillon: 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400',
    validee: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400',
    lettree: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
    annulee: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400',
  };
  
  const labels = {
    brouillon: 'Brouillon',
    validee: 'ValidÃ©e',
    lettree: 'LettrÃ©e',
    annulee: 'AnnulÃ©e',
  };
  
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${variants[variant] || variants.brouillon}`}>
      {labels[variant] || children}
    </span>
  );
};

const Button = ({ children, variant = 'default', size = 'md', className = '', ...props }) => {
  const variants = {
    default: 'bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200',
    primary: 'bg-blue-600 hover:bg-blue-700 text-white border-transparent',
    ghost: 'bg-transparent hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-300 border-transparent',
  };
  
  const sizes = {
    sm: 'px-2 py-1 text-xs',
    md: 'px-3 py-1.5 text-sm',
    lg: 'px-4 py-2 text-base',
    icon: 'p-1.5',
  };
  
  return (
    <button
      className={`inline-flex items-center justify-center gap-1.5 rounded-lg font-medium transition-colors ${variants[variant]} ${sizes[size]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
};

const Input = ({ className = '', ...props }) => (
  <input
    className={`w-full px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm ${className}`}
    {...props}
  />
);

const Select = ({ children, className = '', ...props }) => (
  <select
    className={`px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 ${className}`}
    {...props}
  >
    {children}
  </select>
);

// ============================================================================
// Composant SmartGrid Principal
// ============================================================================

const SmartGrid = () => {
  // Ã‰tat du thÃ¨me
  const [isDark, setIsDark] = useState(false);
  
  // DonnÃ©es
  const [data] = useState(() => generateEcritures(200));
  
  // Ã‰tat de la grille
  const [searchQuery, setSearchQuery] = useState('');
  const [sortConfig, setSortConfig] = useState({ column: null, direction: 'asc' });
  const [filters, setFilters] = useState({});
  const [selectedRows, setSelectedRows] = useState(new Set());
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(15);
  const [groupBy, setGroupBy] = useState(null);
  const [expandedGroups, setExpandedGroups] = useState(new Set());
  const [showColumnMenu, setShowColumnMenu] = useState(false);
  const [showFilterPanel, setShowFilterPanel] = useState(false);
  const [contextMenu, setContextMenu] = useState(null);
  const [visibleColumns, setVisibleColumns] = useState({
    date: true,
    journal: true,
    piece: true,
    compte: true,
    libelle: true,
    debit: true,
    credit: true,
    statut: true,
    utilisateur: true,
  });

  // Configuration des colonnes
  const columns = [
    { id: 'date', label: 'Date', width: 100, type: 'date', sortable: true, filterable: true },
    { id: 'journal', label: 'Journal', width: 80, align: 'center', sortable: true, filterable: true },
    { id: 'piece', label: 'NÂ° PiÃ¨ce', width: 120, sortable: true },
    { id: 'compte', label: 'Compte', width: 180, sortable: true, filterable: true },
    { id: 'libelle', label: 'LibellÃ©', width: 250, flex: 1, sortable: true, filterable: true },
    { id: 'debit', label: 'DÃ©bit', width: 130, type: 'currency', align: 'right', sortable: true },
    { id: 'credit', label: 'CrÃ©dit', width: 130, type: 'currency', align: 'right', sortable: true },
    { id: 'statut', label: 'Statut', width: 110, align: 'center', sortable: true, filterable: true },
    { id: 'utilisateur', label: 'Utilisateur', width: 140, sortable: true, filterable: true },
  ];

  // Filtrage et tri des donnÃ©es
  const processedData = useMemo(() => {
    let result = [...data];

    // Recherche globale
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      result = result.filter(row =>
        Object.values(row).some(val => 
          String(val).toLowerCase().includes(query)
        )
      );
    }

    // Filtres par colonne
    Object.entries(filters).forEach(([column, value]) => {
      if (value) {
        result = result.filter(row => {
          const cellValue = String(row[column]).toLowerCase();
          return cellValue.includes(value.toLowerCase());
        });
      }
    });

    // Tri
    if (sortConfig.column) {
      result.sort((a, b) => {
        let aVal = a[sortConfig.column];
        let bVal = b[sortConfig.column];
        
        // Gestion des types
        if (typeof aVal === 'number' && typeof bVal === 'number') {
          return sortConfig.direction === 'asc' ? aVal - bVal : bVal - aVal;
        }
        
        aVal = String(aVal || '');
        bVal = String(bVal || '');
        
        const comparison = aVal.localeCompare(bVal, 'fr', { numeric: true });
        return sortConfig.direction === 'asc' ? comparison : -comparison;
      });
    }

    return result;
  }, [data, searchQuery, filters, sortConfig]);

  // Groupage des donnÃ©es
  const groupedData = useMemo(() => {
    if (!groupBy) return null;

    const groups = new Map();
    processedData.forEach(row => {
      const key = row[groupBy] || '(Vide)';
      if (!groups.has(key)) {
        groups.set(key, { key, rows: [], totals: { debit: 0, credit: 0 } });
      }
      const group = groups.get(key);
      group.rows.push(row);
      group.totals.debit += row.debit || 0;
      group.totals.credit += row.credit || 0;
    });

    return Array.from(groups.values()).sort((a, b) => 
      String(a.key).localeCompare(String(b.key))
    );
  }, [processedData, groupBy]);

  // Pagination
  const totalItems = groupBy ? groupedData?.length || 0 : processedData.length;
  const totalPages = Math.ceil(totalItems / pageSize);
  
  const paginatedData = useMemo(() => {
    if (groupBy) return groupedData;
    const start = (page - 1) * pageSize;
    return processedData.slice(start, start + pageSize);
  }, [processedData, groupedData, groupBy, page, pageSize]);

  // Calcul des totaux
  const totals = useMemo(() => {
    const totalDebit = processedData.reduce((sum, r) => sum + (r.debit || 0), 0);
    const totalCredit = processedData.reduce((sum, r) => sum + (r.credit || 0), 0);
    return { debit: totalDebit, credit: totalCredit, balanced: totalDebit === totalCredit };
  }, [processedData]);

  // Handlers
  const handleSort = (columnId) => {
    setSortConfig(prev => ({
      column: columnId,
      direction: prev.column === columnId && prev.direction === 'asc' ? 'desc' : 'asc'
    }));
  };

  const handleSelectAll = () => {
    if (selectedRows.size === processedData.length) {
      setSelectedRows(new Set());
    } else {
      setSelectedRows(new Set(processedData.map(r => r.id)));
    }
  };

  const handleSelectRow = (id, e) => {
    setSelectedRows(prev => {
      const next = new Set(prev);
      if (e?.shiftKey && prev.size > 0) {
        // SÃ©lection de plage
        const ids = processedData.map(r => r.id);
        const lastSelected = Array.from(prev).pop();
        const startIdx = ids.indexOf(lastSelected);
        const endIdx = ids.indexOf(id);
        const [from, to] = startIdx < endIdx ? [startIdx, endIdx] : [endIdx, startIdx];
        ids.slice(from, to + 1).forEach(rowId => next.add(rowId));
      } else if (e?.ctrlKey || e?.metaKey) {
        // SÃ©lection multiple
        if (next.has(id)) {
          next.delete(id);
        } else {
          next.add(id);
        }
      } else {
        // SÃ©lection simple
        next.clear();
        next.add(id);
      }
      return next;
    });
  };

  const toggleGroup = (key) => {
    setExpandedGroups(prev => {
      const next = new Set(prev);
      if (next.has(key)) {
        next.delete(key);
      } else {
        next.add(key);
      }
      return next;
    });
  };

  const formatCurrency = (value) => {
    if (!value) return '-';
    return new Intl.NumberFormat('fr-FR', { 
      style: 'decimal',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0 
    }).format(value);
  };

  const handleContextMenu = (e, row, column) => {
    e.preventDefault();
    setContextMenu({
      x: e.clientX,
      y: e.clientY,
      row,
      column,
    });
  };

  // Fermer le menu contextuel
  useEffect(() => {
    const handleClick = () => setContextMenu(null);
    const handleEscape = (e) => e.key === 'Escape' && setContextMenu(null);
    
    document.addEventListener('click', handleClick);
    document.addEventListener('keydown', handleEscape);
    return () => {
      document.removeEventListener('click', handleClick);
      document.removeEventListener('keydown', handleEscape);
    };
  }, []);

  // Rendu d'une cellule
  const renderCell = (row, column) => {
    const value = row[column.id];
    
    switch (column.id) {
      case 'compte':
        return (
          <div className="flex flex-col leading-tight">
            <span className="font-mono font-medium">{row.compte}</span>
            <span className="text-xs text-slate-500 dark:text-slate-400 truncate">{row.libelleCompte}</span>
          </div>
        );
      case 'debit':
      case 'credit':
        return (
          <span className={`font-mono ${value > 0 ? 'text-slate-900 dark:text-slate-100' : 'text-slate-400'}`}>
            {formatCurrency(value)}
          </span>
        );
      case 'statut':
        return <Badge variant={value}>{value}</Badge>;
      case 'date':
        return (
          <span className="font-mono text-slate-600 dark:text-slate-300">
            {new Date(value).toLocaleDateString('fr-FR')}
          </span>
        );
      default:
        return <span className="truncate">{value}</span>;
    }
  };

  // Rendu du header de colonne
  const renderHeader = (column) => {
    const isSorted = sortConfig.column === column.id;
    const isFiltered = filters[column.id];
    
    return (
      <div
        className={`flex items-center gap-1 px-3 py-3 text-left text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700 select-none transition-colors ${column.align === 'right' ? 'justify-end' : column.align === 'center' ? 'justify-center' : ''}`}
        style={{ width: column.width, flexGrow: column.flex || 0 }}
        onClick={() => column.sortable && handleSort(column.id)}
        onContextMenu={(e) => handleContextMenu(e, null, column)}
      >
        <span className="truncate">{column.label}</span>
        {column.sortable && isSorted && (
          <span className="text-blue-600 dark:text-blue-400">
            {sortConfig.direction === 'asc' ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
          </span>
        )}
        {isFiltered && (
          <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
        )}
      </div>
    );
  };

  // Classes pour le thÃ¨me
  const themeClass = isDark ? 'dark' : '';

  return (
    <div className={`${themeClass} h-screen flex flex-col bg-slate-100 dark:bg-slate-900 transition-colors`}>
      {/* Header */}
      <header className="flex-shrink-0 bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <h1 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <span className="text-2xl">ðŸ“Š</span>
              SmartGrid OHADA
            </h1>
            
            {/* Statistiques */}
            <div className="hidden md:flex items-center gap-4 px-4 py-1.5 bg-slate-50 dark:bg-slate-700/50 rounded-lg text-sm">
              <span className="text-slate-600 dark:text-slate-300">
                <strong>DÃ©bit:</strong> {formatCurrency(totals.debit)} XAF
              </span>
              <span className="text-slate-600 dark:text-slate-300">
                <strong>CrÃ©dit:</strong> {formatCurrency(totals.credit)} XAF
              </span>
              <span className={`px-2 py-0.5 rounded text-xs font-semibold ${totals.balanced ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400' : 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400'}`}>
                {totals.balanced ? 'âœ“ Ã‰quilibrÃ©' : 'âœ— DÃ©sÃ©quilibrÃ©'}
              </span>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="icon" onClick={() => setIsDark(!isDark)}>
              {isDark ? <Sun size={18} /> : <Moon size={18} />}
            </Button>
          </div>
        </div>
      </header>

      {/* Toolbar */}
      <div className="flex-shrink-0 bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 px-4 py-2">
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-2 flex-1">
            {/* Recherche */}
            <div className="relative w-full max-w-xs">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <Input
                type="text"
                placeholder="Rechercher..."
                value={searchQuery}
                onChange={(e) => { setSearchQuery(e.target.value); setPage(1); }}
                className="pl-9 pr-8"
              />
              {searchQuery && (
                <button
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                  onClick={() => setSearchQuery('')}
                >
                  <X size={16} />
                </button>
              )}
            </div>

            {/* Filtres rapides */}
            <Button 
              variant={showFilterPanel ? 'primary' : 'default'} 
              size="md"
              onClick={() => setShowFilterPanel(!showFilterPanel)}
            >
              <Filter size={16} />
              Filtres
              {Object.keys(filters).filter(k => filters[k]).length > 0 && (
                <span className="ml-1 px-1.5 py-0.5 text-xs bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded-full">
                  {Object.keys(filters).filter(k => filters[k]).length}
                </span>
              )}
            </Button>

            {/* Groupement */}
            <Select 
              value={groupBy || ''} 
              onChange={(e) => { setGroupBy(e.target.value || null); setExpandedGroups(new Set()); }}
            >
              <option value="">Pas de groupement</option>
              <option value="journal">Par Journal</option>
              <option value="statut">Par Statut</option>
              <option value="utilisateur">Par Utilisateur</option>
              <option value="compte">Par Compte</option>
            </Select>
          </div>

          <div className="flex items-center gap-2">
            {/* Colonnes */}
            <div className="relative">
              <Button variant="default" size="md" onClick={() => setShowColumnMenu(!showColumnMenu)}>
                <Columns size={16} />
                Colonnes
              </Button>
              
              {showColumnMenu && (
                <div className="absolute right-0 top-full mt-1 w-48 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-1 z-50">
                  {columns.map(col => (
                    <label 
                      key={col.id}
                      className="flex items-center gap-2 px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-700 cursor-pointer text-sm text-slate-700 dark:text-slate-200"
                    >
                      <input
                        type="checkbox"
                        checked={visibleColumns[col.id]}
                        onChange={(e) => setVisibleColumns(prev => ({ ...prev, [col.id]: e.target.checked }))}
                        className="rounded border-slate-300 text-blue-600 focus:ring-blue-500"
                      />
                      {col.label}
                    </label>
                  ))}
                </div>
              )}
            </div>

            {/* Export */}
            <Button variant="default" size="md">
              <Download size={16} />
              Exporter
            </Button>

            {/* SÃ©lection info */}
            {selectedRows.size > 0 && (
              <span className="text-sm text-slate-600 dark:text-slate-300 px-3 py-1.5 bg-blue-50 dark:bg-blue-900/30 rounded-lg">
                {selectedRows.size} sÃ©lectionnÃ©(s)
              </span>
            )}
          </div>
        </div>

        {/* Panel de filtres */}
        {showFilterPanel && (
          <div className="mt-3 p-3 bg-slate-50 dark:bg-slate-700/30 rounded-lg">
            <div className="flex items-center gap-4 flex-wrap">
              {columns.filter(c => c.filterable).map(col => (
                <div key={col.id} className="flex items-center gap-2">
                  <label className="text-xs font-medium text-slate-600 dark:text-slate-400">
                    {col.label}:
                  </label>
                  {col.id === 'statut' ? (
                    <Select
                      value={filters[col.id] || ''}
                      onChange={(e) => setFilters(prev => ({ ...prev, [col.id]: e.target.value }))}
                      className="text-xs py-1"
                    >
                      <option value="">Tous</option>
                      <option value="brouillon">Brouillon</option>
                      <option value="validee">ValidÃ©e</option>
                      <option value="lettree">LettrÃ©e</option>
                      <option value="annulee">AnnulÃ©e</option>
                    </Select>
                  ) : col.id === 'journal' ? (
                    <Select
                      value={filters[col.id] || ''}
                      onChange={(e) => setFilters(prev => ({ ...prev, [col.id]: e.target.value }))}
                      className="text-xs py-1"
                    >
                      <option value="">Tous</option>
                      <option value="VT">Ventes</option>
                      <option value="AC">Achats</option>
                      <option value="BQ">Banque</option>
                      <option value="CA">Caisse</option>
                      <option value="OD">OpÃ©rations diverses</option>
                    </Select>
                  ) : (
                    <Input
                      type="text"
                      placeholder="Filtrer..."
                      value={filters[col.id] || ''}
                      onChange={(e) => setFilters(prev => ({ ...prev, [col.id]: e.target.value }))}
                      className="w-32 text-xs py-1"
                    />
                  )}
                </div>
              ))}
              <Button 
                variant="ghost" 
                size="sm"
                onClick={() => setFilters({})}
                className="text-red-600 dark:text-red-400"
              >
                <X size={14} />
                Effacer tout
              </Button>
            </div>
          </div>
        )}
      </div>

      {/* Grid Container */}
      <div className="flex-1 overflow-hidden p-4">
        <div className="h-full bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden flex flex-col">
          {/* Table Header */}
          <div className="flex-shrink-0 bg-slate-50 dark:bg-slate-700/50 border-b border-slate-200 dark:border-slate-600">
            <div className="flex">
              {/* Checkbox column */}
              <div className="flex items-center justify-center w-12 px-3 py-3">
                <input
                  type="checkbox"
                  checked={selectedRows.size === processedData.length && processedData.length > 0}
                  onChange={handleSelectAll}
                  className="rounded border-slate-300 dark:border-slate-600 text-blue-600 focus:ring-blue-500"
                />
              </div>
              {columns.filter(col => visibleColumns[col.id]).map(col => (
                <div key={col.id}>
                  {renderHeader(col)}
                </div>
              ))}
            </div>
          </div>

          {/* Table Body */}
          <div className="flex-1 overflow-auto">
            {groupBy && groupedData ? (
              // Vue groupÃ©e
              groupedData.map(group => (
                <div key={group.key}>
                  {/* Group header */}
                  <div 
                    className="flex items-center gap-3 px-4 py-2.5 bg-slate-100 dark:bg-slate-700 border-b border-slate-200 dark:border-slate-600 cursor-pointer hover:bg-slate-150 dark:hover:bg-slate-600 transition-colors sticky top-0"
                    onClick={() => toggleGroup(group.key)}
                  >
                    <span className="text-slate-500 dark:text-slate-400">
                      {expandedGroups.has(group.key) ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                    </span>
                    <span className="font-semibold text-slate-800 dark:text-slate-100">{group.key}</span>
                    <span className="text-xs text-slate-500 dark:text-slate-400 bg-slate-200 dark:bg-slate-600 px-2 py-0.5 rounded-full">
                      {group.rows.length} lignes
                    </span>
                    <div className="ml-auto flex items-center gap-6 text-sm font-mono">
                      <span className="text-slate-600 dark:text-slate-300">
                        DÃ©bit: <strong>{formatCurrency(group.totals.debit)}</strong>
                      </span>
                      <span className="text-slate-600 dark:text-slate-300">
                        CrÃ©dit: <strong>{formatCurrency(group.totals.credit)}</strong>
                      </span>
                    </div>
                  </div>
                  
                  {/* Group rows */}
                  {expandedGroups.has(group.key) && group.rows.map((row, idx) => (
                    <div
                      key={row.id}
                      className={`flex border-b border-slate-100 dark:border-slate-700 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors cursor-pointer ${selectedRows.has(row.id) ? 'bg-blue-100 dark:bg-blue-900/30' : idx % 2 === 1 ? 'bg-slate-50/50 dark:bg-slate-800/50' : ''}`}
                      onClick={(e) => handleSelectRow(row.id, e)}
                      onContextMenu={(e) => handleContextMenu(e, row, null)}
                    >
                      <div className="flex items-center justify-center w-12 px-3 py-2.5">
                        <input
                          type="checkbox"
                          checked={selectedRows.has(row.id)}
                          onChange={() => {}}
                          onClick={(e) => e.stopPropagation()}
                          className="rounded border-slate-300 dark:border-slate-600 text-blue-600 focus:ring-blue-500"
                        />
                      </div>
                      {columns.filter(col => visibleColumns[col.id]).map(col => (
                        <div
                          key={col.id}
                          className={`flex items-center px-3 py-2.5 text-sm text-slate-700 dark:text-slate-200 ${col.align === 'right' ? 'justify-end' : col.align === 'center' ? 'justify-center' : ''}`}
                          style={{ width: col.width, flexGrow: col.flex || 0 }}
                        >
                          {renderCell(row, col)}
                        </div>
                      ))}
                    </div>
                  ))}
                </div>
              ))
            ) : (
              // Vue plate
              paginatedData.map((row, idx) => (
                <div
                  key={row.id}
                  className={`flex border-b border-slate-100 dark:border-slate-700 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors cursor-pointer ${selectedRows.has(row.id) ? 'bg-blue-100 dark:bg-blue-900/30' : idx % 2 === 1 ? 'bg-slate-50/50 dark:bg-slate-800/50' : ''}`}
                  onClick={(e) => handleSelectRow(row.id, e)}
                  onContextMenu={(e) => handleContextMenu(e, row, null)}
                >
                  <div className="flex items-center justify-center w-12 px-3 py-2.5">
                    <input
                      type="checkbox"
                      checked={selectedRows.has(row.id)}
                      onChange={() => {}}
                      onClick={(e) => e.stopPropagation()}
                      className="rounded border-slate-300 dark:border-slate-600 text-blue-600 focus:ring-blue-500"
                    />
                  </div>
                  {columns.filter(col => visibleColumns[col.id]).map(col => (
                    <div
                      key={col.id}
                      className={`flex items-center px-3 py-2.5 text-sm text-slate-700 dark:text-slate-200 ${col.align === 'right' ? 'justify-end' : col.align === 'center' ? 'justify-center' : ''}`}
                      style={{ width: col.width, flexGrow: col.flex || 0 }}
                    >
                      {renderCell(row, col)}
                    </div>
                  ))}
                </div>
              ))
            )}
            
            {/* Empty state */}
            {processedData.length === 0 && (
              <div className="flex flex-col items-center justify-center py-16 text-slate-400 dark:text-slate-500">
                <Search size={48} className="mb-4 opacity-50" />
                <p className="text-lg font-medium">Aucun rÃ©sultat</p>
                <p className="text-sm">Essayez de modifier vos filtres</p>
              </div>
            )}
          </div>

          {/* Footer / Pagination */}
          <div className="flex-shrink-0 flex items-center justify-between px-4 py-3 bg-slate-50 dark:bg-slate-700/50 border-t border-slate-200 dark:border-slate-600">
            <div className="text-sm text-slate-600 dark:text-slate-400">
              {processedData.length} enregistrement(s)
              {searchQuery || Object.keys(filters).filter(k => filters[k]).length > 0 ? ` (filtrÃ© de ${data.length})` : ''}
            </div>
            
            {!groupBy && (
              <div className="flex items-center gap-4">
                <div className="flex items-center gap-2">
                  <span className="text-sm text-slate-600 dark:text-slate-400">Lignes:</span>
                  <Select 
                    value={pageSize} 
                    onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1); }}
                    className="py-1"
                  >
                    <option value={10}>10</option>
                    <option value={15}>15</option>
                    <option value={25}>25</option>
                    <option value={50}>50</option>
                    <option value={100}>100</option>
                  </Select>
                </div>
                
                <div className="flex items-center gap-1">
                  <Button variant="ghost" size="icon" onClick={() => setPage(1)} disabled={page === 1}>
                    <ChevronsLeft size={16} />
                  </Button>
                  <Button variant="ghost" size="icon" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>
                    <ChevronLeft size={16} />
                  </Button>
                  <span className="px-3 text-sm text-slate-600 dark:text-slate-400">
                    Page {page} / {totalPages || 1}
                  </span>
                  <Button variant="ghost" size="icon" onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page >= totalPages}>
                    <ChevronRight size={16} />
                  </Button>
                  <Button variant="ghost" size="icon" onClick={() => setPage(totalPages)} disabled={page >= totalPages}>
                    <ChevronsRight size={16} />
                  </Button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Context Menu */}
      {contextMenu && (
        <div
          className="fixed bg-white dark:bg-slate-800 rounded-lg shadow-xl border border-slate-200 dark:border-slate-700 py-1 z-50 min-w-[180px]"
          style={{ left: contextMenu.x, top: contextMenu.y }}
        >
          {contextMenu.row && (
            <>
              <button className="w-full flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700">
                <span>ðŸ‘ï¸</span> Voir les dÃ©tails
              </button>
              <button className="w-full flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700">
                <span>âœï¸</span> Modifier
              </button>
              <button className="w-full flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700">
                <span>ðŸ“‹</span> Copier
              </button>
              <div className="h-px bg-slate-200 dark:bg-slate-700 my-1" />
              <button className="w-full flex items-center gap-2 px-4 py-2 text-sm text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/30">
                <span>ðŸ—‘ï¸</span> Supprimer
              </button>
            </>
          )}
          {contextMenu.column && (
            <>
              <button 
                className="w-full flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700"
                onClick={() => { handleSort(contextMenu.column.id); setContextMenu(null); }}
              >
                <span>â¬†ï¸</span> Trier croissant
              </button>
              <button 
                className="w-full flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700"
                onClick={() => { setSortConfig({ column: contextMenu.column.id, direction: 'desc' }); setContextMenu(null); }}
              >
                <span>â¬‡ï¸</span> Trier dÃ©croissant
              </button>
              <div className="h-px bg-slate-200 dark:bg-slate-700 my-1" />
              <button 
                className="w-full flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700"
                onClick={() => { setGroupBy(contextMenu.column.id); setContextMenu(null); }}
              >
                <span>ðŸ“Š</span> Grouper par cette colonne
              </button>
              <div className="h-px bg-slate-200 dark:bg-slate-700 my-1" />
              <button 
                className="w-full flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700"
                onClick={() => { setVisibleColumns(prev => ({ ...prev, [contextMenu.column.id]: false })); setContextMenu(null); }}
              >
                <span>ðŸ‘ï¸â€ðŸ—¨ï¸</span> Masquer la colonne
              </button>
            </>
          )}
        </div>
      )}

      {/* Footer */}
      <footer className="flex-shrink-0 bg-white dark:bg-slate-800 border-t border-slate-200 dark:border-slate-700 px-4 py-2">
        <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
          <span>SmartGrid v1.0 â€” Architecture Multi-Gammes OHADA/CEMAC</span>
          <span>ðŸ’¡ Clic droit pour menu contextuel â€¢ Shift+Clic pour sÃ©lection multiple</span>
        </div>
      </footer>
    </div>
  );
};

export default SmartGrid;
