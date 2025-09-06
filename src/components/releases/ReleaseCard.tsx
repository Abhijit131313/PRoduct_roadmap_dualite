import React from 'react';
import { format } from 'date-fns';
import { Target, Calendar, MoreVertical, CheckCircle } from 'lucide-react';

interface ReleaseCardProps {
  release: any;
  features: any[];
}

export const ReleaseCard: React.FC<ReleaseCardProps> = ({ release, features }) => {
  const completedFeatures = features.filter(f => f.status === 'completed').length;
  const progress = features.length > 0 ? (completedFeatures / features.length) * 100 : 0;

  return (
    <div className="bg-white rounded-lg shadow hover:shadow-md transition-all p-6 border border-gray-200 h-full flex flex-col">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
            <Target className="w-5 h-5 text-purple-600" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">{release.name}</h3>
            <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800`}>
              {release.status}
            </span>
          </div>
        </div>
        <button className="text-gray-400 hover:text-gray-600">
          <MoreVertical className="w-5 h-5" />
        </button>
      </div>

      {release.description && (
        <p className="text-gray-600 text-sm mb-4 line-clamp-2 flex-grow">
          {release.description}
        </p>
      )}

      <div className="space-y-3">
        <div className="flex items-center text-sm text-gray-500">
          <Calendar className="w-4 h-4 mr-2" />
          <span>Target: {format(new Date(release.target_date), 'MMM d, yyyy')}</span>
        </div>
        
        <div>
          <div className="flex items-center justify-between text-sm text-gray-600 mb-1">
            <span>Progress ({completedFeatures}/{features.length} features)</span>
            <span>{Math.round(progress)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-purple-600 h-2 rounded-full transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>
      </div>
      
      <div className="mt-4 pt-4 border-t border-gray-200">
        <h4 className="text-sm font-medium text-gray-800 mb-2">Features in this release:</h4>
        {features.length > 0 ? (
          <div className="space-y-2">
            {features.slice(0, 3).map(feature => (
              <div key={feature.id} className="flex items-center text-sm text-gray-600">
                {feature.status === 'completed' 
                  ? <CheckCircle className="w-4 h-4 text-green-500 mr-2 flex-shrink-0" />
                  : <div className="w-2 h-2 rounded-full bg-gray-300 mr-3 flex-shrink-0" />
                }
                <span className="truncate">{feature.title}</span>
              </div>
            ))}
            {features.length > 3 && (
              <p className="text-xs text-gray-500 mt-1">+ {features.length - 3} more</p>
            )}
          </div>
        ) : (
          <p className="text-sm text-gray-500 italic">No features assigned yet.</p>
        )}
      </div>
    </div>
  );
};
