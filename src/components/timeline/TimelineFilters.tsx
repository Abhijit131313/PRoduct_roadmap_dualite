import React from 'react';

interface TimelineFiltersProps {
  filters: {
    status: string[];
    priority: string[];
    assignee: string[];
  };
  onFiltersChange: (filters: any) => void;
}

const STATUSES = [
  { value: 'backlog', label: 'Backlog' },
  { value: 'planned', label: 'Planned' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
];

const PRIORITIES = [
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
  { value: 'critical', label: 'Critical' },
];

export const TimelineFilters: React.FC<TimelineFiltersProps> = ({
  filters,
  onFiltersChange,
}) => {
  const handleStatusChange = (status: string) => {
    const newStatuses = filters.status.includes(status)
      ? filters.status.filter(s => s !== status)
      : [...filters.status, status];
    
    onFiltersChange({ ...filters, status: newStatuses });
  };

  const handlePriorityChange = (priority: string) => {
    const newPriorities = filters.priority.includes(priority)
      ? filters.priority.filter(p => p !== priority)
      : [...filters.priority, priority];
    
    onFiltersChange({ ...filters, priority: newPriorities });
  };

  return (
    <div className="bg-gray-50 rounded-lg p-4 space-y-4">
      <div>
        <h4 className="text-sm font-medium text-gray-900 mb-2">Status</h4>
        <div className="flex flex-wrap gap-2">
          {STATUSES.map((status) => (
            <label key={status.value} className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={filters.status.includes(status.value)}
                onChange={() => handleStatusChange(status.value)}
                className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              />
              <span className="text-sm text-gray-700">{status.label}</span>
            </label>
          ))}
        </div>
      </div>

      <div>
        <h4 className="text-sm font-medium text-gray-900 mb-2">Priority</h4>
        <div className="flex flex-wrap gap-2">
          {PRIORITIES.map((priority) => (
            <label key={priority.value} className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={filters.priority.includes(priority.value)}
                onChange={() => handlePriorityChange(priority.value)}
                className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              />
              <span className="text-sm text-gray-700">{priority.label}</span>
            </label>
          ))}
        </div>
      </div>
    </div>
  );
};
