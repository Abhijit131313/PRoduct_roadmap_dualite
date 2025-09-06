import React from 'react';
import { motion } from 'framer-motion';
import { Building, Users, Calendar, ChevronRight } from 'lucide-react';
import { format } from 'date-fns';

interface Organization {
  id: string;
  name: string;
  description: string | null;
  created_at: string;
  role: 'admin' | 'editor' | 'viewer';
}

interface OrganizationListProps {
  organizations: Organization[];
  selectedOrganization: Organization | null;
  onSelectOrganization: (org: Organization) => void;
}

export const OrganizationList: React.FC<OrganizationListProps> = ({
  organizations,
  selectedOrganization,
  onSelectOrganization,
}) => {
  if (organizations.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <Building className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-900 mb-2">No Organizations Yet</h3>
        <p className="text-gray-600 mb-4">
          Create your first organization to start building product roadmaps.
        </p>
        <p className="text-sm text-gray-500">
          Organizations help you manage teams, projects, and roadmaps in one place.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-gray-900">Your Organizations</h2>
        <p className="text-sm text-gray-600">{organizations.length} organization{organizations.length !== 1 ? 's' : ''}</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {organizations.map((org, index) => (
          <motion.div
            key={org.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            onClick={() => onSelectOrganization(org)}
            className={`bg-white rounded-lg shadow hover:shadow-md transition-all cursor-pointer p-6 border-2 ${
              selectedOrganization?.id === org.id
                ? 'border-blue-500 ring-2 ring-blue-200'
                : 'border-transparent hover:border-gray-200'
            }`}
          >
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center space-x-3">
                <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                  <Building className="w-6 h-6 text-blue-600" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">{org.name}</h3>
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                    org.role === 'admin' 
                      ? 'bg-purple-100 text-purple-800'
                      : org.role === 'editor'
                      ? 'bg-green-100 text-green-800'
                      : 'bg-gray-100 text-gray-800'
                  }`}>
                    {org.role}
                  </span>
                </div>
              </div>
              {selectedOrganization?.id === org.id && (
                <ChevronRight className="w-5 h-5 text-blue-600" />
              )}
            </div>

            {org.description && (
              <p className="text-gray-600 text-sm mb-4 line-clamp-2">
                {org.description}
              </p>
            )}

            <div className="flex items-center justify-between text-sm text-gray-500">
              <div className="flex items-center space-x-1">
                <Calendar className="w-4 h-4" />
                <span>Created {format(new Date(org.created_at), 'MMM d, yyyy')}</span>
              </div>
              <div className="flex items-center space-x-1">
                <Users className="w-4 h-4" />
                <span>Team</span>
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      {selectedOrganization && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-blue-50 border border-blue-200 rounded-lg p-4"
        >
          <p className="text-blue-800 text-sm">
            <strong>{selectedOrganization.name}</strong> is currently selected. 
            Use the navigation above to manage projects and roadmaps for this organization.
          </p>
        </motion.div>
      )}
    </div>
  );
};
