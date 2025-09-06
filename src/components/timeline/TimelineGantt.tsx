import React from 'react';
import { motion } from 'framer-motion';
import { Calendar, Target } from 'lucide-react';
import { format, addDays, differenceInDays, startOfMonth, endOfMonth } from 'date-fns';

interface TimelineGanttProps {
  initiatives: any[];
  features: any[];
  releases: any[];
  zoomLevel: string;
  filters: any;
  onUpdateInitiative: (id: string, updates: any) => void;
}

export const TimelineGantt: React.FC<TimelineGanttProps> = ({
  initiatives,
  features,
  releases,
  zoomLevel,
  filters,
  onUpdateInitiative,
}) => {
  // Filter initiatives based on date range
  const initiativesWithDates = initiatives.filter(
    initiative => initiative.start_date && initiative.end_date
  );

  if (initiativesWithDates.length === 0) {
    return (
      <div className="p-8 text-center">
        <Calendar className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-900 mb-2">No Timeline Data</h3>
        <p className="text-gray-600 mb-4">
          Add start and end dates to your initiatives to see them in the timeline.
        </p>
      </div>
    );
  }

  // Calculate timeline range
  const allDates = initiativesWithDates.flatMap(initiative => [
    new Date(initiative.start_date),
    new Date(initiative.end_date),
  ]);
  
  const minDate = new Date(Math.min(...allDates.map(d => d.getTime())));
  const maxDate = new Date(Math.max(...allDates.map(d => d.getTime())));
  
  const timelineStart = startOfMonth(minDate);
  const timelineEnd = endOfMonth(maxDate);
  const totalDays = differenceInDays(timelineEnd, timelineStart);

  // Generate timeline headers based on zoom level
  const generateTimelineHeaders = () => {
    const headers = [];
    let current = timelineStart;
    
    while (current <= timelineEnd) {
      headers.push(format(current, 'MMM yyyy'));
      current = addDays(current, 30); // Approximate month
    }
    
    return headers;
  };

  const timelineHeaders = generateTimelineHeaders();

  const calculateBarPosition = (startDate: string, endDate: string) => {
    const start = new Date(startDate);
    const end = new Date(endDate);
    
    const startOffset = differenceInDays(start, timelineStart);
    const duration = differenceInDays(end, start);
    
    const leftPercent = (startOffset / totalDays) * 100;
    const widthPercent = (duration / totalDays) * 100;
    
    return {
      left: `${Math.max(0, leftPercent)}%`,
      width: `${Math.min(100 - leftPercent, widthPercent)}%`,
    };
  };

  return (
    <div className="overflow-auto">
      {/* Timeline Header */}
      <div className="sticky top-0 bg-gray-50 border-b border-gray-200 p-4">
        <div className="flex">
          <div className="w-80 flex-shrink-0">
            <h4 className="text-sm font-medium text-gray-900">Initiative</h4>
          </div>
          <div className="flex-1 grid grid-cols-12 gap-2">
            {timelineHeaders.map((header, index) => (
              <div key={index} className="text-xs text-gray-600 text-center">
                {header}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Timeline Content */}
      <div className="p-4 space-y-3">
        {initiativesWithDates.map((initiative, index) => {
          const barPosition = calculateBarPosition(
            initiative.start_date,
            initiative.end_date
          );
          
          return (
            <motion.div
              key={initiative.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: index * 0.1 }}
              className="flex items-center group hover:bg-gray-50 rounded-lg p-2"
            >
              <div className="w-80 flex-shrink-0">
                <div className="flex items-center space-x-3">
                  <div
                    className="w-4 h-4 rounded-full"
                    style={{ backgroundColor: initiative.color || '#3B82F6' }}
                  />
                  <div>
                    <h5 className="text-sm font-medium text-gray-900">
                      {initiative.title}
                    </h5>
                    <p className="text-xs text-gray-500">
                      {format(new Date(initiative.start_date), 'MMM d')} - {' '}
                      {format(new Date(initiative.end_date), 'MMM d, yyyy')}
                    </p>
                  </div>
                </div>
              </div>
              
              <div className="flex-1 relative h-8">
                <div
                  className="absolute h-6 rounded-full opacity-80 hover:opacity-100 transition-opacity cursor-pointer"
                  style={{
                    backgroundColor: initiative.color || '#3B82F6',
                    ...barPosition,
                  }}
                >
                  <div className="h-full bg-white bg-opacity-20 rounded-full relative">
                    <div
                      className="h-full bg-white bg-opacity-40 rounded-full transition-all duration-300"
                      style={{ width: `${initiative.progress || 0}%` }}
                    />
                  </div>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Releases */}
      {releases.length > 0 && (
        <div className="border-t border-gray-200 p-4">
          <h4 className="text-sm font-medium text-gray-900 mb-3 flex items-center">
            <Target className="w-4 h-4 mr-2" />
            Releases
          </h4>
          <div className="space-y-2">
            {releases.map((release) => (
              <div key={release.id} className="flex items-center space-x-3 text-sm">
                <div className="w-3 h-3 bg-green-500 rounded-full" />
                <span className="font-medium">{release.name}</span>
                <span className="text-gray-500">
                  {format(new Date(release.target_date), 'MMM d, yyyy')}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
