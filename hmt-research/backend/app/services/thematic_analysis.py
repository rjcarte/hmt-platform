import openai
from typing import Dict, List, Optional
import json
from datetime import datetime
from sqlalchemy.orm import Session
from ..models.scenario import ThematicAnalysis, ScenarioResponse
from ..core.config import settings

class ThematicAnalyzer:
    def __init__(self):
        self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
    
    async def analyze_transcript(self, transcript: str, context: Dict) -> Dict:
        """Perform thematic analysis on think-aloud transcript"""
        
        if not transcript or len(transcript.strip()) < 50:
            return {
                "themes": [],
                "codes": [],
                "key_concepts": [],
                "sentiment": {"score": 0, "magnitude": 0}
            }
        
        prompt = f"""
        Perform a thematic analysis on this cybersecurity decision-making transcript.
        
        Context:
        Scenario: {context.get('scenario_title', 'Unknown')}
        Decision Made: {context.get('selected_option', 'Unknown')}
        
        Transcript: {transcript[:3000]}
        
        Identify and return in JSON format:
        1. themes: Main themes as an array of objects with 'theme' and 'evidence' (quote from transcript)
        2. codes: Specific codes identified (array of strings)
        3. key_concepts: Important domain-specific concepts mentioned (array of strings)
        4. cognitive_strategies: Decision-making strategies used
        5. uncertainty_expressions: Phrases indicating uncertainty or doubt
        6. risk_factors: Risk-related considerations mentioned
        """
        
        try:
            response = self.client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {
                        "role": "system", 
                        "content": "You are an expert in thematic analysis of cybersecurity decision-making. Always respond with valid JSON."
                    },
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                response_format={"type": "json_object"}
            )
            
            analysis = json.loads(response.choices[0].message.content)
            
            # Ensure all expected fields exist
            return {
                "themes": analysis.get("themes", []),
                "codes": analysis.get("codes", []),
                "key_concepts": analysis.get("key_concepts", []),
                "cognitive_strategies": analysis.get("cognitive_strategies", []),
                "uncertainty_expressions": analysis.get("uncertainty_expressions", []),
                "risk_factors": analysis.get("risk_factors", []),
                "sentiment": {"score": 0.5, "magnitude": 1.0}  # Placeholder
            }
            
        except Exception as e:
            print(f"Thematic analysis error: {e}")
            return {
                "themes": [{"theme": "Error in analysis", "evidence": str(e)}],
                "codes": [],
                "key_concepts": [],
                "sentiment": {"score": 0, "magnitude": 0}
            }
    
    async def transcribe_audio(self, audio_file_path: str) -> str:
        """Transcribe audio using OpenAI Whisper API"""
        try:
            with open(audio_file_path, "rb") as audio_file:
                transcript = self.client.audio.transcriptions.create(
                    model=settings.WHISPER_MODEL,
                    file=audio_file,
                    response_format="text"
                )
            return transcript
        except Exception as e:
            print(f"Transcription error: {e}")
            return ""
    
    def save_analysis(self, db: Session, response_id: str, analysis_data: Dict, user_id: str) -> ThematicAnalysis:
        """Save thematic analysis to database"""
        analysis = ThematicAnalysis(
            response_id=response_id,
            themes=analysis_data.get("themes", []),
            codes=analysis_data.get("codes", {}),
            key_concepts=analysis_data.get("key_concepts", []),
            sentiment=analysis_data.get("sentiment", {}),
            analyzed_by=user_id
        )
        
        db.add(analysis)
        db.commit()
        db.refresh(analysis)
        
        return analysis