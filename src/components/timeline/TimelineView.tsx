import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Calendar, ZoomIn, ZoomOut, Filter } from 'lucide-react';
import { Button } from '../ui/Button';
import { TimelineGantt } from './TimelineGantt';
import { TimelineFilters } from './TimelineFilters';

interface TimelineViewProps {
  initiatives: any[];
  features: any[];
  releases: any[];
  onUpdateInitiative: (id: string, updates: any) => void;
}

export const TimelineView: React.FC<TimelineViewProps> = ({
  initiatives,
  features,
  releases,
  onUpdateInitiative,
}) => {
  const [showFilters, setShowFilters] = useState(false);
  const [zoomLevel, setZoomLevel] = useState('month');
  const [filters, setFilters] = useState({
    status: [],
    priority: [],
    assignee: [],
  });

  const handleZoomIn = () => {
    if (zoomLevel === 'year') setZoomLevel('quarter');
    else if (zoomLevel === 'quarter') setZoomLevel('month');
    else if (zoomLevel === 'month') setZoomLevel('week');
  };

  const handleZoomOut = () => {
    if (zoomLevel === 'week') setZoomLevel('month');
    else if (zoomLevel === 'month') setZoomLevel('quarter');
    else if (zoomLevel === 'quarter') setZoomLevel('year');
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <h3 className="text-lg font-semibold text-gray-900">Timeline View</h3>
          <div className="flex items-center space-x-2">
            <Button
              size="sm"
              variant="outline"
              onClick={handleZoomOut}
              disabled={zoomLevel === 'year'}
            >
              <ZoomOut className="w-4 h-4" />
            </Button>
            <span className="text-sm text-gray-600 capitalize">{zoomLevel}</span>
            <Button
              size="sm"
              variant="outline"
              onClick={handleZoomIn}
              disabled={zoomLevel === 'week'}
            >
              <ZoomIn className="w-4 h-4" />
            </Button>
          </div>
        </div>
        
        <div className="flex items-center space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowFilters(!showFilters)}
          >
            <Filter className="w-4 h-4 mr-2" />
            Filters
          </Button>
        </div>
      </div>

      {showFilters && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          exit={{ opacity: 0, height: 0 }}
        >
          <TimelineFilters filters={filters} onFiltersChange={setFilters} />
        </motion.div>
      )}

      <div className="bg-white rounded-lg shadow overflow-hidden">
        {initiatives.length === 0 ? (
          <div className="p-8 text-center">
            <Calendar className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-2">No Timeline Data</h3>
            <p className="text-gray-600">
              Create initiatives with dates to see them in the timeline view.
            </p>
          </div>
        ) : (
          <TimelineGantt
            initiatives={initiatives}
            features={features}
            releases={releases}
            zoomLevel={zoomLevel}
            filters={filters}
            onUpdateInitiative={onUpdateInitiative}
          />
        )}
      </div>
    </div>
  );
};
