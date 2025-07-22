CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table update
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    preferences TEXT DEFAULT '{}'
);

-- Existing tables remain the same

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop tables if they exist (for clean rebuild)
DROP TABLE IF EXISTS scenario_responses CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS scenarios CASCADE;

CREATE TABLE scenarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    description TEXT NOT NULL,
    context TEXT NOT NULL,
    decision_point TEXT NOT NULL,
    options JSONB NOT NULL,
    meta_data JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE experiments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    scenario_sequence JSONB NOT NULL,
    config JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    experiment_id UUID REFERENCES experiments(id),
    participant_id VARCHAR(50) NOT NULL,
    operator_id VARCHAR(50) NOT NULL,
    start_time TIMESTAMP DEFAULT NOW(),
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active',
    meta_data JSONB DEFAULT '{}'
);

CREATE TABLE scenario_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES sessions(id),
    scenario_id UUID REFERENCES scenarios(id),
    step_number INTEGER NOT NULL,
    presented_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP,
    selected_option VARCHAR(50),
    custom_response TEXT,
    confidence_rating INTEGER CHECK (confidence_rating BETWEEN 1 AND 5),
    risk_rating INTEGER CHECK (risk_rating BETWEEN 1 AND 5),
    response_time_ms INTEGER,
    think_aloud_transcript TEXT
);

-- Create indexes
CREATE INDEX idx_sessions_experiment ON sessions(experiment_id);
CREATE INDEX idx_responses_session ON scenario_responses(session_id);
CREATE INDEX idx_responses_scenario ON scenario_responses(scenario_id);

