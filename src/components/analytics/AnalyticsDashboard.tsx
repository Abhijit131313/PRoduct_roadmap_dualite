import React from 'react';
import { motion } from 'framer-motion';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, PieChart, Pie, Cell, LineChart, Line, ResponsiveContainer } from 'recharts';
import { TrendingUp, Target, Clock, CheckCircle } from 'lucide-react';

interface AnalyticsDashboardProps {
  initiatives: any[];
  features: any[];
  releases: any[];
}

const COLORS = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6'];

export const AnalyticsDashboard: React.FC<AnalyticsDashboardProps> = ({
  initiatives,
  features,
  releases,
}) => {
  // Calculate metrics
  const completedInitiatives = initiatives.filter(i => i.status === 'completed').length;
  const inProgressInitiatives = initiatives.filter(i => i.status === 'in_progress').length;
  const totalInitiatives = initiatives.length;
  
  const completedFeatures = features.filter(f => f.status === 'completed').length;
  const totalFeatures = features.length;

  const averageProgress = initiatives.length > 0
    ? initiatives.reduce((sum, i) => sum + (i.progress || 0), 0) / initiatives.length
    : 0;

  // Status distribution data
  const statusData = [
    { name: 'Backlog', value: initiatives.filter(i => i.status === 'backlog').length },
    { name: 'Planned', value: initiatives.filter(i => i.status === 'planned').length },
    { name: 'In Progress', value: inProgressInitiatives },
    { name: 'Completed', value: completedInitiatives },
    { name: 'Cancelled', value: initiatives.filter(i => i.status === 'cancelled').length },
  ].filter(item => item.value > 0);

  // Priority distribution data
  const priorityData = [
    { name: 'Low', value: initiatives.filter(i => i.priority === 'low').length },
    { name: 'Medium', value: initiatives.filter(i => i.priority === 'medium').length },
    { name: 'High', value: initiatives.filter(i => i.priority === 'high').length },
    { name: 'Critical', value: initiatives.filter(i => i.priority === 'critical').length },
  ].filter(item => item.value > 0);

  // Progress over time (mock data for demo)
  const progressData = [
    { month: 'Jan', completed: 2, planned: 8 },
    { month: 'Feb', completed: 5, planned: 10 },
    { month: 'Mar', completed: 8, planned: 12 },
    { month: 'Apr', completed: 12, planned: 15 },
    { month: 'May', completed: 15, planned: 18 },
    { month: 'Jun', completed: 18, planned: 20 },
  ];

  const metrics = [
    {
      title: 'Total Initiatives',
      value: totalInitiatives,
      change: '+12%',
      trend: 'up',
      icon: Target,
      color: 'bg-blue-500',
    },
    {
      title: 'Completed',
      value: completedInitiatives,
      change: `${totalInitiatives > 0 ? Math.round((completedInitiatives / totalInitiatives) * 100) : 0}%`,
      trend: 'up',
      icon: CheckCircle,
      color: 'bg-green-500',
    },
    {
      title: 'In Progress',
      value: inProgressInitiatives,
      change: `${totalInitiatives > 0 ? Math.round((inProgressInitiatives / totalInitiatives) * 100) : 0}%`,
      trend: 'up',
      icon: Clock,
      color: 'bg-yellow-500',
    },
    {
      title: 'Avg Progress',
      value: `${Math.round(averageProgress)}%`,
      change: '+5%',
      trend: 'up',
      icon: TrendingUp,
      color: 'bg-purple-500',
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Analytics Dashboard</h3>
        <p className="text-gray-600">Track progress and analyze trends across your roadmap.</p>
      </div>

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {metrics.map((metric, index) => {
          const Icon = metric.icon;
          return (
            <motion.div
              key={metric.title}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              className="bg-white rounded-lg shadow p-6"
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-gray-600 text-sm font-medium">{metric.title}</p>
                  <p className="text-2xl font-bold text-gray-900 mt-1">{metric.value}</p>
                  <p className={`text-sm mt-1 ${
                    metric.trend === 'up' ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {metric.change} from last month
                  </p>
                </div>
                <div className={`w-12 h-12 ${metric.color} rounded-lg flex items-center justify-center`}>
                  <Icon className="w-6 h-6 text-white" />
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Status Distribution */}
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          className="bg-white rounded-lg shadow p-6"
        >
          <h4 className="text-lg font-semibold text-gray-900 mb-4">Status Distribution</h4>
          {statusData.length > 0 ? (
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={statusData}
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                  label
                >
                  {statusData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="text-center py-8 text-gray-500">No data available</div>
          )}
        </motion.div>

        {/* Priority Distribution */}
        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          className="bg-white rounded-lg shadow p-6"
        >
          <h4 className="text-lg font-semibold text-gray-900 mb-4">Priority Distribution</h4>
          {priorityData.length > 0 ? (
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={priorityData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="value" fill="#3B82F6" />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="text-center py-8 text-gray-500">No data available</div>
          )}
        </motion.div>
      </div>

      {/* Progress Over Time */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-lg shadow p-6"
      >
        <h4 className="text-lg font-semibold text-gray-900 mb-4">Progress Over Time</h4>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={progressData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="month" />
            <YAxis />
            <Tooltip />
            <Line type="monotone" dataKey="completed" stroke="#10B981" strokeWidth={3} />
            <Line type="monotone" dataKey="planned" stroke="#3B82F6" strokeWidth={3} />
          </LineChart>
        </ResponsiveContainer>
      </motion.div>

      {/* Key Insights */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-lg shadow p-6"
      >
        <h4 className="text-lg font-semibold text-gray-900 mb-4">Key Insights</h4>
        <div className="space-y-3">
          <div className="p-4 bg-blue-50 rounded-lg">
            <h5 className="font-medium text-blue-900">Completion Rate</h5>
            <p className="text-blue-700 text-sm">
              {totalInitiatives > 0 
                ? `${Math.round((completedInitiatives / totalInitiatives) * 100)}% of initiatives have been completed`
                : 'No initiatives to analyze yet'
              }
            </p>
          </div>
          <div className="p-4 bg-green-50 rounded-lg">
            <h5 className="font-medium text-green-900">Feature Delivery</h5>
            <p className="text-green-700 text-sm">
              {totalFeatures > 0
                ? `${completedFeatures} out of ${totalFeatures} features completed (${Math.round((completedFeatures / totalFeatures) * 100)}%)`
                : 'No features to track yet'
              }
            </p>
          </div>
          <div className="p-4 bg-yellow-50 rounded-lg">
            <h5 className="font-medium text-yellow-900">Overall Progress</h5>
            <p className="text-yellow-700 text-sm">
              Average initiative progress is {Math.round(averageProgress)}%
            </p>
          </div>
        </div>
      </motion.div>
    </div>
  );
};
